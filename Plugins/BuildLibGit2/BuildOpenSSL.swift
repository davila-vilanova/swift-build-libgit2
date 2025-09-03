import Foundation
import PackagePlugin

func buildOpenSSL(
    context: PluginContext,
    platform: Platform,
    arguments: [String]
) throws {
    let fileManager = FileManager.default

    let libsDir = openSSLLibsDirectoryURL(for: context, platform: platform)
    let logFile = context.pluginWorkDirectoryURL.appending(
        component: "openssl_build_\(platform.rawValue).log"
    )
    let buildDir = context.pluginWorkDirectoryURL
        .appending(component: "openssl_build_\(platform.rawValue)")

    for url in [libsDir, buildDir, logFile] {
        if fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }

    for dir in [libsDir, buildDir] {
        try fileManager.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    fileManager.createFile(atPath: logFile.path(), contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    let srcDir = try cloneRepository(with: context)

    try cleanBuild(
        with: context,
        in: buildDir,
        loggingTo: logFileHandle
    )  // TODO possibly I don't need to call this now that I have a dedicated build dir that is deleted and recreated
    try configureBuild(
        with: context,
        srcDir: srcDir,
        buildDir: buildDir,
        for: platform,
        installURL: libsDir,
        loggingTo: logFileHandle
    )
    try runMake(
        with: context,
        in: buildDir,
        loggingTo: logFileHandle
    )
    try runMakeInstall(
        with: context,
        in: buildDir,
        loggingTo: logFileHandle
    )

    print("OpenSSL libraries for \(platform.rawValue) can be found at \(libsDir.path())")
}

func openSSLLibsDirectoryURL(
    for context: PluginContext,
    platform: Platform
) -> URL {
    context.pluginWorkDirectoryURL.appending(
        components: "openssl_libs", libraryDirectoryName(for: platform)
    )
}

private func cloneRepository(with context: PluginContext) throws -> URL {
    try cloneRepository(
        at: "https://github.com/openssl/openssl.git",
        with: context,
        tag: "openssl-3.5.1",
        into: "openssl_src"
    )
}

private func cleanBuild(
    with context: PluginContext,
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    let makeTool = try context.tool(named: "make")

    let makeClean = Process()
    makeClean.currentDirectoryURL = buildDir
    makeClean.executableURL = fakeMakeURL(context) ?? makeTool.url
    makeClean.arguments = ["clean"]
    makeClean.standardOutput = logFileHandle
    makeClean.standardError = logFileHandle
    try makeClean.run()
    makeClean.waitUntilExit()
}

private func configureBuild(
    with context: PluginContext,
    srcDir: URL,
    buildDir: URL,
    for platform: Platform,
    installURL: URL,
    loggingTo logFileHandle: FileHandle,
) throws {
    print("Running Configure in \(srcDir.path())...")

    let configure = Process()
    configure.currentDirectoryURL = buildDir
    configure.executableURL = fakeConfigureURL(context) ?? srcDir.appending(component: "Configure")

    let developerBasePath = try getXcodeDeveloperPath(context: context)

    let platformArgs =
        switch platform {
        case .iPhoneOS: ["ios64-xcrun"]
        case .iPhoneSimulator: ["iossimulator-arm64-xcrun"]
        }
    configure.arguments =
        platformArgs + [
            "no-shared",
            "no-dso",
            "no-apps",
            "no-docs",
            "no-ui-console",
            "zlib",
            "--prefix=\(installURL.path(percentEncoded: true))",
        ]

    configure.standardOutput = logFileHandle
    configure.standardError = logFileHandle
    try configure.run()
    configure.waitUntilExit()
    guard configure.terminationStatus == 0 else {
        throw PluginError("Configure failed. See log for details.")
    }
    print("Configure completed successfully.")
}

private func runMake(
    with context: PluginContext,
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    print("Running Make...")

    let makeTool = try context.tool(named: "make")

    let make = Process()
    make.currentDirectoryURL = buildDir
    make.executableURL = fakeMakeURL(context) ?? makeTool.url
    make.arguments = [
        "-j", "\(getSystemCPUCount())",
        "build_libs",
    ]
    make.standardOutput = logFileHandle
    make.standardError = logFileHandle
    try make.run()
    make.waitUntilExit()
    guard make.terminationStatus == 0 else {
        throw PluginError("Make failed. See log for details.")
    }
    print("Make completed successfully.")
}

private func runMakeInstall(
    with context: PluginContext,
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    print("Running Make Install...")

    let makeTool = try context.tool(named: "make")

    let makeInstall = Process()
    makeInstall.currentDirectoryURL = buildDir
    makeInstall.executableURL = fakeMakeURL(context) ?? makeTool.url
    makeInstall.arguments = ["install_sw"]
    makeInstall.standardOutput = logFileHandle
    makeInstall.standardError = logFileHandle
    try makeInstall.run()
    makeInstall.waitUntilExit()
    guard makeInstall.terminationStatus == 0 else {
        throw PluginError("Make Install failed. See log for details.")
    }
    print("Make Install completed successfully.")
}

@discardableResult
func createOpenSSLXCFrameworks(
    with context: PluginContext,
    platforms: [Platform]
) throws -> [URL] {
    try ["libssl", "libcrypto"].map { libname in
        let libDirsByPlatform = LibraryLocationsByPlatform(
            uniqueKeysWithValues: platforms.map { platform in
                let libDir = openSSLLibsDirectoryURL(
                    for: context, platform: platform
                )
                return (
                    platform,  // key
                    LibraryLocations(  // value
                        binary: libDir.appending(component: "lib/\(libname).a"),
                        headers: nil  // libDir.appending(component: "include")
                    )
                )
            }
        )
        return try createXCFramework(
            named: libname,
            with: context,
            fromLibrariesAt: libDirsByPlatform,
            placeInto: try packageFrameworksDirectory(for: context),
        )
    }
}
