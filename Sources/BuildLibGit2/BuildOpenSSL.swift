import Foundation

func buildOpenSSL(
    context: Context,
    target: Target,  // a target per platform, with potentially multiple archs
) throws {
    for singleArchTarget in target.splitIntoArchitectures() {
        let platform = singleArchTarget.platform
        let architectures = singleArchTarget.architectures
        assert(
            architectures.count == 1,
            "Expected single architecture target, got \(architectures) for platform \(platform)"
        )
        let architecture = architectures.first!

        let sourceDirURL = singleArchTarget.sourceDirURL(context)
        let buildDirURL = singleArchTarget.buildDirURL(context)
        let installDirURL = singleArchTarget.installDirURL(context)

        let logFileHandle = try prepareBuild(
            libraryName: singleArchTarget.libraryName,
            buildDirURL: buildDirURL,
            installDirURL: installDirURL,
            context: context,
            cloneRepository: {
                try cloneRepository(
                    into: sourceDirURL,
                    context: context
                )
            },
        )

        try configureBuild(
            with: context,
            platform: platform,
            architecture: architecture,
            srcURL: sourceDirURL,
            buildURL: buildDirURL,
            installURL: installDirURL,
            loggingTo: logFileHandle
        )
        try runMake(
            with: context,
            in: buildDirURL,
            loggingTo: logFileHandle
        )
        try runMakeInstall(
            with: context,
            in: buildDirURL,
            loggingTo: logFileHandle
        )

        print(
            "OpenSSL libraries for \(platform), \(architecture) "
                + "can be found at \(installDirURL.path())"
        )
    }

    if target.architectures.count > 1 {
        try combineArchitectures(for: target, context: context)
    }
}

private func combineArchitectures(for target: Target, context: Context) throws {
    let fileManager = FileManager.default

    let destinationBinaryDir = target.installDirURL(context)
        .appending(component: target.binariesDirRelativePath)
    if fileManager.fileExists(atPath: destinationBinaryDir.path()) {
        try fileManager.removeItem(at: destinationBinaryDir)
    }
    try fileManager.createDirectory(at: destinationBinaryDir, withIntermediateDirectories: true)

    func combineArchitecturesForBinary(named binaryName: String) throws {
        let destinationFatBinary =
            destinationBinaryDir
            .appending(component: binaryName + ".a")

        let lipo = Process()
        lipo.executableURL = try context.urlForTool(named: "lipo")
        lipo.arguments =
            [
                "-create"
            ]
            + target.splitIntoArchitectures().map {
                $0.installDirURL(context)
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

private func cloneRepository(into srcURL: URL, context: Context) throws {
    try cloneRepository(
        at: "https://github.com/openssl/openssl.git",
        with: context,
        tag: "openssl-3.5.1",
        into: srcURL
    )
}

private func configureBuild(
    with context: Context,
    platform: Platform,
    architecture: Architecture,
    srcURL: URL,
    buildURL: URL,
    installURL: URL,
    loggingTo logFileHandle: FileHandle,
) throws {
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

    try runProcess(configure, .mergeOutputError(.fileHandle(logFileHandle)))
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
    with context: Context,
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    let make = Process()
    make.currentDirectoryURL = buildDir
    make.executableURL = try context.urlForTool(named: "make")
    make.arguments = [
        "-j", "\(getSystemCPUCount())",
        "build_libs",
    ]
    try runProcess(make, .mergeOutputError(.fileHandle(logFileHandle)))
}

private func runMakeInstall(
    with context: Context,
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    let makeInstall = Process()
    makeInstall.currentDirectoryURL = buildDir
    makeInstall.executableURL = try context.urlForTool(named: "make")
    makeInstall.arguments = ["install_sw"]
    try runProcess(
        makeInstall,
        .mergeOutputError(.fileHandle(logFileHandle)),
        name: "make install_sw")
}

@discardableResult
func createOpenSSLXCFrameworks(
    targets: [Target],  // a target for each platform
    context: Context,
) throws -> [URL] {
    // at least one target required
    guard let firstTarget = targets.first else {
        return []
    }

    // one framework per binary name
    let namesAndBinaries = ["libssl", "libcrypto"].map { binaryName in
        // I want the binaries for this binaryName and for each platform and combined archs (e.g. for each target)
        let binaries = targets.map {
            $0.installDirURL(context)
                .appending(components: "lib", binaryName + ".a")
        }
        return (binaryName, binaries)
    }

    // The headers each target points to are equivalent
    // but need to get the headers from a single-architecture build
    let headers = firstTarget.splitIntoArchitectures().first!.installDirURL(context).appending(
        components: "include", "openssl")

    return try namesAndBinaries.map { (name, binaries) -> URL in
        try createXCFramework(
            named: name,
            with: context,
            binaries: binaries,
            headers: headers,
            placeInto: context.outputDirectoryURL
        )
    }
}
