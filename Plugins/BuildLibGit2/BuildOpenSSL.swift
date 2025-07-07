import Foundation
import PackagePlugin

func buildOpenSSL(context: PluginContext, arguments: [String]) throws {
    let fileManager = FileManager.default

    let libsDir = openSSLLibsDirectoryURL(for: context)
    let logFile = context.pluginWorkDirectoryURL.appending(component: "openssl_build.log")

    for url in [libsDir, logFile] {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    try fileManager.createDirectory(at: libsDir, withIntermediateDirectories: true)
    try fileManager.createFile(atPath: logFile.path, contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    let srcDir = try cloneRepository(with: context)
    try configureBuild(
        with: context, in: srcDir, installURL: libsDir, loggingTo: logFileHandle)
    try runMake(with: context, in: srcDir, loggingTo: logFileHandle)
    try runMakeInstall(with: context, in: srcDir, loggingTo: logFileHandle)
    print("OpenSSL libraries can be found at \(libsDir.path())")
    try createXCFrameworks(
        with: context,
        fromLibrariesAt: libsDir,
        placeInto: try packageFrameworksDirectory(for: context),
        loggingTo: logFileHandle
    )
}

func openSSLLibsDirectoryURL(
    for context: PluginContext
) -> URL {
    context.pluginWorkDirectoryURL.appending(component: "openssl_libs")
}

private func cloneRepository(with context: PluginContext) throws -> URL {
    try cloneRepository(
        at: "https://github.com/openssl/openssl.git",
        with: context,
        tag: "openssl-3.5.1",
        into: "openssl_src"
    )
}

private func configureBuild(
    with context: PluginContext,
    in srcDir: URL,
    installURL: URL,
    loggingTo logFileHandle: FileHandle,
) throws {
    print("Running Configure in \(srcDir.path())...")

    let configure = Process()
    configure.currentDirectoryURL = srcDir
    configure.executableURL = srcDir.appending(component: "Configure")
    configure.arguments = [
        "ios64-cross",
        "--prefix=\"\(installURL.path)\"",
    ]
    try setCrossCompilationEnvVars(with: context, into: configure)
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
    in srcDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    print("Running Make...")

    let makeTool = try context.tool(named: "make")

    let make = Process()
    make.currentDirectoryURL = srcDir
    make.executableURL = makeTool.url
    make.arguments = [
        "-j", "\(getSystemCPUCount())",
        "build_libs",
    ]
    try setCrossCompilationEnvVars(with: context, into: make)
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
    in srcDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    print("Running Make Install...")

    let makeTool = try context.tool(named: "make")

    let makeInstall = Process()
    makeInstall.currentDirectoryURL = srcDir
    makeInstall.executableURL = makeTool.url
    makeInstall.arguments = ["install_sw"]
    try setCrossCompilationEnvVars(with: context, into: makeInstall)
    makeInstall.standardOutput = logFileHandle
    makeInstall.standardError = logFileHandle
    try makeInstall.run()
    makeInstall.waitUntilExit()
    guard makeInstall.terminationStatus == 0 else {
        throw PluginError("Make Install failed. See log for details.")
    }
    print("Make Install completed successfully.")
}

private func createXCFrameworks(
    with context: PluginContext,
    fromLibrariesAt outputDir: URL,
    placeInto frameworksDir: URL,
    loggingTo logFileHandle: FileHandle
) throws -> [URL] {

    return try ["libssl", "libcrypto"].map { libname in
        try createXCFramework(
            named: libname,
            with: context,
            fromLibraryAt: outputDir.appending(component: "lib/\(libname).a"),
            placeInto: frameworksDir,
            loggingTo: logFileHandle
        )
    }
}

@discardableResult
private func setCrossCompilationEnvVars(
    with context: PluginContext,
    into process: Process
) throws -> Process {
    let developerBasePath = try getXcodeDeveloperPath(context: context)

    process.environment = [
        "CROSS_COMPILE": "\(developerBasePath)/Toolchains/XcodeDefault.xctoolchain/usr/bin/",
        "CROSS_TOP": "\(developerBasePath)/Platforms/iPhoneOS.platform/Developer",
        "CROSS_SDK": "iPhoneOS.sdk",
    ]
    return process
}
