import Dependencies
import Foundation

// Target: a target per platform, with potentially multiple archs
func buildOpenSSL(target: Target) throws {
    @Dependency(\.cloneRepository) var cloneRepository

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
            try configureOpenSSLBuild(
                platform: platform,
                architecture: architecture,
                srcURL: sourceDirURL,
                buildURL: buildDirURL,
                installURL: installDirURL,
                loggingTo: logFileHandle
            ),
            .mergeOutputError(.fileHandle(logFileHandle)))

        try runProcess(
            try runMake(
                in: buildDirURL,
                loggingTo: logFileHandle
            ),
            .mergeOutputError(.fileHandle(logFileHandle)))

        try runProcess(
            try runMakeInstall(
                in: buildDirURL,
                loggingTo: logFileHandle
            ),
            .mergeOutputError(.fileHandle(logFileHandle)),
            name: "make install_sw")

        print(
            "OpenSSL libraries for \(platform), \(architecture) "
                + "can be found at \(installDirURL.path())"
        )
    }

    if target.architectures.count > 1 {
        try combineArchitectures(for: target)
    }
}

func configureOpenSSLBuild(
    platform: Platform,
    architecture: Architecture,
    srcURL: URL,
    buildURL: URL,
    installURL: URL,
    loggingTo logFileHandle: FileHandle,
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

private func targetName(for platform: Platform, architecture: Architecture) throws -> String {
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

private func runMake(
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws -> Process {
    @Dependency(\.urlForTool) var urlForTool
    let make = Process()
    make.currentDirectoryURL = buildDir
    make.executableURL = try urlForTool("make")
    make.arguments = [
        "-j", "\(getSystemCPUCount())",
        "build_libs",
    ]
    return make
}

private func runMakeInstall(
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws -> Process {
    @Dependency(\.urlForTool) var urlForTool
    let makeInstall = Process()
    makeInstall.currentDirectoryURL = buildDir
    makeInstall.executableURL = try urlForTool("make")
    makeInstall.arguments = ["install_sw"]
    return makeInstall
}

private func combineArchitectures(for target: Target) throws {
    @Dependency(\.urlForTool) var urlForTool
    @Dependency(\.createDirectories) var createDirectories
    @Dependency(\.copyFileOrDirectory) var copyDirectory

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
func createOpenSSLXCFrameworks(
    targets: [Target],  // a target for each platform
) throws -> [URL] {
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
