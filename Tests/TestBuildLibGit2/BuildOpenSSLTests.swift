import Dependencies
import Foundation
import Testing

@testable import BuildLibGit2

struct BuildOpenSSLTests {
    @Test(arguments: [
        (Platform.iPhoneOS, Architecture.arm64, Optional.some("ios64-xcrun")),
        (.iPhoneOS, .x86_64, nil),
        (.iPhoneSimulator, .arm64, "iossimulator-arm64-xcrun"),
        (.iPhoneSimulator, .x86_64, "iossimulator-x86_64-xcrun"),
        (.macOS, .arm64, "darwin64-arm64"),
        (.macOS, .x86_64, "darwin64-x86_64"),
    ])
    func createConfigureProcess(
        platform: Platform,
        architecture: Architecture,
        expectedTarget: String?
    ) throws {
        let processResult = Result {
            try BuildOpenSSL.createConfigureProcess(
                platform: platform,
                architecture: architecture,
                srcURL: .init(filePath: "/path/to/source"),
                buildURL: .init(filePath: "/path/to/build"),
                installURL: .init(filePath: "/path/to/install"),
            )
        }

        guard let expectedTarget = expectedTarget else {
            #expect(throws: IncompatiblePlatformArchitectureError.self) {
                try processResult.get()
            }
            return
        }

        let configure = try processResult.get()

        #expect(configure.executableURL == .init(filePath: "/path/to/source/Configure"))
        #expect(configure.currentDirectoryURL == .init(filePath: "/path/to/build/"))

        let arguments = try #require(configure.arguments)
        let firstArgument = try #require(arguments.first)

        #expect(firstArgument == expectedTarget)
        #expect(arguments.contains("no-shared"))
        #expect(arguments.contains("no-dso"))
        #expect(arguments.contains("no-apps"))
        #expect(arguments.contains("no-docs"))
        #expect(arguments.contains("no-ui-console"))
        #expect(arguments.contains("zlib"))
        #expect(arguments.contains("--prefix=/path/to/install"))
    }

    @Test func createMakeProcess() throws {
        try withDependencies {
            $0.urlForTool = { (toolName: String) -> URL in
                URL(filePath: "/path/to/tools/\(toolName)")
            }
            $0.systemCPUCount = 12
        } operation: {
            let make = try BuildOpenSSL.createMakeProcess(
                buildDir: .init(filePath: "/path/to/build"))

            #expect(make.executableURL == .init(filePath: "/path/to/tools/make"))
            #expect(make.currentDirectoryURL == .init(filePath: "/path/to/build/"))

            let arguments = try #require(make.arguments)
            #expect(arguments == ["-j", "12", "build_libs"])
        }
    }

    @Test func createMakeInstallProcess() throws {
        try withDependencies {
            $0.urlForTool = { URL(filePath: "/path/to/tools/\($0)") }
        } operation: {
            let makeInstall = try BuildOpenSSL.createMakeInstallProcess(
                buildDir: .init(filePath: "/path/to/build"))

            #expect(makeInstall.executableURL == .init(filePath: "/path/to/tools/make"))
            #expect(makeInstall.currentDirectoryURL == .init(filePath: "/path/to/build/"))

            let arguments = try #require(makeInstall.arguments)
            #expect(arguments == ["install_sw"])
        }
    }

    @Test func combineArchitectures() throws {
        let target = Target(
            libraryName: "openssl",
            platform: .macOS,
            architectures: [.arm64, .x86_64],
            binariesDirRelativePath: "lib",
            headersDirRelativePath: "include.openssl"
        ) // TODO: parametrize?

        let sideEffectsTracker = SideEffectsTracker()

        try withDependencies {
            $0.workDirectoryURL = URL(filePath: "/path/to/work/directory")
            $0.urlForTool = { URL(filePath: "/path/to/tools/\($0)") }
            $0.createDirectories = sideEffectsTracker.createDirectories
            $0.copyFileOrDirectory = sideEffectsTracker.copyFileOrDirectory
            $0.runProcess = sideEffectsTracker.runProcess
        } operation: {
            try BuildOpenSSL.combineArchitectures(for: target)
        }

        #expect(sideEffectsTracker.actions == [
            "create directories /path/to/work/directory/openssl/macOS-arm64-x86_64/install/lib, /path/to/work/directory/openssl/macOS-arm64-x86_64/install/", // TODO: this second one is redundant
            "copy /path/to/work/directory/openssl/macOS-arm64/install/include.openssl to /path/to/work/directory/openssl/macOS-arm64-x86_64/install/include.openssl",
            "run process /path/to/tools/lipo -create /path/to/work/directory/openssl/macOS-arm64/install/lib/libssl.a /path/to/work/directory/openssl/macOS-x86_64/install/lib/libssl.a -output /path/to/work/directory/openssl/macOS-arm64-x86_64/install/lib/libssl.a",
            "run process /path/to/tools/lipo -create /path/to/work/directory/openssl/macOS-arm64/install/lib/libcrypto.a /path/to/work/directory/openssl/macOS-x86_64/install/lib/libcrypto.a -output /path/to/work/directory/openssl/macOS-arm64-x86_64/install/lib/libcrypto.a"
        ])
    }

    @Test func createXCFrameworks() throws {

        let targets = [Platform.macOS, .iPhoneOS, .iPhoneSimulator].map {
            Target(
                libraryName: "openssl",
                platform: $0,
                architectures: [.arm64, .x86_64],
                binariesDirRelativePath: "lib",
                headersDirRelativePath: "include.openssl"
            )
        }

        let sideEffectsTracker = SideEffectsTracker()

        try withDependencies {
            $0.outputDirectoryURL = URL(filePath: "/path/to/output/directory")
            $0.workDirectoryURL = URL(filePath: "/path/to/work/directory")
            $0.urlForTool = { URL(filePath: "/path/to/tools/\($0)") }
            $0.removeFileOrDirectory = sideEffectsTracker.removeFileOrDirectory
            $0.runProcess = sideEffectsTracker.runProcess

            $0.createDirectories = sideEffectsTracker.createDirectories
            $0.copyFileOrDirectory = sideEffectsTracker.copyFileOrDirectory
        } operation: {
            try BuildOpenSSL.createXCFrameworks(for: targets)
        }

        #expect(sideEffectsTracker.actions == [
            "remove /path/to/output/directory/libssl.xcframework",
            "run process /path/to/tools/xcodebuild -create-xcframework -library /path/to/work/directory/openssl/macOS-arm64-x86_64/install/lib/libssl.a -headers /path/to/work/directory/openssl/macOS-arm64-x86_64/install/include.openssl -library /path/to/work/directory/openssl/iPhoneOS-arm64-x86_64/install/lib/libssl.a -headers /path/to/work/directory/openssl/macOS-arm64-x86_64/install/include.openssl -library /path/to/work/directory/openssl/iPhoneSimulator-arm64-x86_64/install/lib/libssl.a -headers /path/to/work/directory/openssl/macOS-arm64-x86_64/install/include.openssl -output /path/to/output/directory/libssl.xcframework",
            "remove /path/to/output/directory/libcrypto.xcframework",
            "run process /path/to/tools/xcodebuild -create-xcframework -library /path/to/work/directory/openssl/macOS-arm64-x86_64/install/lib/libcrypto.a -headers /path/to/work/directory/openssl/macOS-arm64-x86_64/install/include.openssl -library /path/to/work/directory/openssl/iPhoneOS-arm64-x86_64/install/lib/libcrypto.a -headers /path/to/work/directory/openssl/macOS-arm64-x86_64/install/include.openssl -library /path/to/work/directory/openssl/iPhoneSimulator-arm64-x86_64/install/lib/libcrypto.a -headers /path/to/work/directory/openssl/macOS-arm64-x86_64/install/include.openssl -output /path/to/output/directory/libcrypto.xcframework"
        ])
    }
}
