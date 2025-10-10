import Dependencies
import Foundation

struct BuildOpenSSL {
    // Target: a target per platform, with potentially multiple archs
    static func build(target: Target) throws {
        @Dependency(\.cloneRepository) var cloneRepository
        @Dependency(\.runProcess) var runProcess

        for singleArchTarget in target.splitIntoArchitectures() {
            let platform = singleArchTarget.platform
            let architectures = singleArchTarget.architectures
            assert(
                architectures.count == 1,
                "Expected single architecture target, got \(architectures) for platform \(platform)"
            )
            let architecture = architectures.first!

            let sourceDirURL = singleArchTarget.sourceDirURL
            let buildDirURL = singleArchTarget.buildDirURL
            let installDirURL = singleArchTarget.installDirURL

            let logFileHandle = try prepareBuild(for: singleArchTarget)
            try cloneRepository(
                "https://github.com/openssl/openssl.git",
                "openssl-3.5.1",
                target.sourceDirURL,
            )

            try runProcess(
                try createConfigureProcess(
                    platform: platform,
                    architecture: architecture,
                    srcURL: sourceDirURL,
                    buildURL: buildDirURL,
                    installURL: installDirURL,
                ),
                .mergeOutputError(.fileHandle(logFileHandle)))

            try runProcess(
                try createMakeProcess(buildDir: buildDirURL),
                .mergeOutputError(.fileHandle(logFileHandle)))

            try runProcess(
                try createMakeInstallProcess(buildDir: buildDirURL),
                .mergeOutputError(.fileHandle(logFileHandle)))

            print(
                "OpenSSL libraries for \(platform), \(architecture) "
                    + "can be found at \(installDirURL.path())"
            )
        }

        if target.architectures.count > 1 {
            try combineArchitectures(for: target)
        }
    }

    static func createConfigureProcess(
        platform: Platform,
        architecture: Architecture,
        srcURL: URL,
        buildURL: URL,
        installURL: URL,
    ) throws -> Process {
        let configure = Process()
        configure.currentDirectoryURL = buildURL
        configure.executableURL = srcURL.appending(component: "Configure")

        configure.arguments =
            [try targetName(for: platform, architecture: architecture)] + [
                "no-shared",
                "no-dso",
                "no-apps",
                "no-docs",
                "no-ui-console",
                "zlib",
                "--prefix=\(installURL.path(percentEncoded: true))",
            ]
        return configure
    }

    static private func targetName(
        for platform: Platform,
        architecture: Architecture
    ) throws -> String {
        switch (platform, architecture) {  // TODO: is this syntax idiomatic?
        case (.iPhoneOS, .arm64): "ios64-xcrun"
        case (.iPhoneOS, .x86_64):
            throw IncompatiblePlatformArchitectureError(
                platform: platform, architecture: architecture)
        case (.iPhoneSimulator, .arm64): "iossimulator-arm64-xcrun"
        case (.iPhoneSimulator, .x86_64): "iossimulator-x86_64-xcrun"
        case (.macOS, .arm64): "darwin64-arm64"
        case (.macOS, .x86_64): "darwin64-x86_64"
        }
    }

    static func createMakeProcess(buildDir: URL) throws -> Process {
        @Dependency(\.urlForTool) var urlForTool
        @Dependency(\.systemCPUCount) var systemCPUCount
        let make = Process()
        make.currentDirectoryURL = buildDir
        make.executableURL = try urlForTool("make")
        make.arguments = [
            "-j", "\(systemCPUCount)",
            "build_libs",
        ]
        return make
    }

    static func createMakeInstallProcess(buildDir: URL) throws -> Process {
        @Dependency(\.urlForTool) var urlForTool
        let makeInstall = Process()
        makeInstall.currentDirectoryURL = buildDir
        makeInstall.executableURL = try urlForTool("make")
        makeInstall.arguments = ["install_sw"]
        return makeInstall
    }

    static func combineArchitectures(for target: Target) throws {
        @Dependency(\.urlForTool) var urlForTool
        @Dependency(\.createDirectories) var createDirectories
        @Dependency(\.copyFileOrDirectory) var copyDirectory
        @Dependency(\.runProcess) var runProcess

        let destinationBinaryDir = target.installDirURL
            .appending(component: target.binariesDirRelativePath)
        let destinationHeadersDir = target.installDirURL
            .appending(component: target.headersDirRelativePath)

        try createDirectories(
            destinationBinaryDir,
            destinationHeadersDir.deletingLastPathComponent()
        )

        // Copy headers
        let oneBuiltTarget = target.splitIntoArchitectures().first!
        let sourceHeadersDir = oneBuiltTarget.installDirURL
            .appending(component: oneBuiltTarget.headersDirRelativePath)
        try copyDirectory(sourceHeadersDir, destinationHeadersDir)

        func combineArchitecturesForBinary(named binaryName: String) throws {
            let destinationFatBinary =
                destinationBinaryDir
                .appending(component: binaryName + ".a")

            let lipo = Process()
            lipo.executableURL = try urlForTool("lipo")
            lipo.arguments =
                [
                    "-create"
                ]
                + target.splitIntoArchitectures().map {
                    $0.installDirURL
                        .appending(components: "lib", "\(binaryName).a")
                        .path()
                } + [
                    "-output",
                    destinationFatBinary.path(),
                ]
            try runProcess(lipo, .inheritFromProcess)  // TODO: what to do with output here? Separate log file? stdout?
        }

        for name in ["libssl", "libcrypto"] {
            try combineArchitecturesForBinary(named: name)
        }

        // TODO: could return "combined targets"
    }

    @discardableResult
    static func createXCFrameworks(for targets: [Target]) throws -> [URL] {
        @Dependency(\.outputDirectoryURL) var outputDirectoryURL

        // at least one target required
        guard let firstTarget = targets.first else {
            return []
        }

        // one framework per binary name
        let namesAndBinaries = ["libssl", "libcrypto"].map { binaryName in
            // I want the binaries for this binaryName and for each platform and combined archs (e.g. for each target)
            let binaries = targets.map {
                $0.installDirURL
                    .appending(components: "lib", binaryName + ".a")
            }
            return (binaryName, binaries)
        }

        // The headers each target points to are equivalent
        let headers = firstTarget.installDirURL
            .appending(path: firstTarget.headersDirRelativePath)

        return try namesAndBinaries.map { (name, binaries) -> URL in
            try createXCFramework(
                named: name,
                binaries: binaries,
                headers: headers,
                placeInto: outputDirectoryURL
            )
        }
    }
}
