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
    func configureArguments(
        platform: Platform,
        architecture: Architecture,
        expectedTarget: String?
    ) throws {
        let processResult = Result {
            try configureOpenSSLBuild(
                platform: platform,
                architecture: architecture,
                srcURL: .init(filePath: "/path/to/source"),
                buildURL: .init(filePath: "/path/to/build"),
                installURL: .init(filePath: "/path/to/install"),
                loggingTo: .nullDevice
            )
        }

        guard let expectedTarget = expectedTarget else {
            #expect(throws: IncompatiblePlatformArchitectureError.self) {
                try processResult.get()
            }
            return
        }

        let process = try processResult.get()
        let arguments = try #require(process.arguments)
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
}

