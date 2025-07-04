import Foundation
import PackagePlugin

func BuildOpenSSL(context: PluginContext, arguments: [String]) throws {
    let sdkInfo = try getSDKInfo(context: context, platform: .iPhoneOS)

    let fileManager = FileManager.default

    let libsDir = context.pluginWorkDirectoryURL.appending(component: "openssl_libs")
    let logFile = context.pluginWorkDirectoryURL.appending(component: "openssl_build.log")
    let packageFrameworksDir = context.package.directoryURL.appending(component: "frameworks")

    for url in [libsDir, logFile] {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    try fileManager.createDirectory(at: libsDir, withIntermediateDirectories: true)
    try fileManager.createFile(atPath: logFile.path, contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    let srcDir = try cloneOpenSSL(with: context)
    try configureBuild(
        with: context, in: srcDir, installURL: libsDir, loggingTo: logFileHandle)
    try runMake(with: context, in: srcDir, loggingTo: logFileHandle)
    try runMakeInstall(with: context, in: srcDir, loggingTo: logFileHandle)
    let frameworkURLs = try createXCFrameworks(
        with: context,
        fromLibrariesAt: libsDir,
        placeInto: packageFrameworksDir,
        loggingTo: logFileHandle
    )
}

private func cloneOpenSSL(with context: PluginContext) throws -> URL {
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
    print("Using \(makeTool.name) at \(makeTool.url.path())")

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
    print("Using \(makeTool.name) at \(makeTool.url.path())")

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
    let xcodebuildTool = try context.tool(named: "xcodebuild")
    print("Using \(xcodebuildTool.name) at \(xcodebuildTool.url.path())")

    return try ["libssl", "libcrypto"].map { libname in
        let frameworkURL = frameworksDir.appending(component: "\(libname).xcframework")
        if FileManager.default.fileExists(atPath: frameworkURL.path) {
            try FileManager.default.removeItem(at: frameworkURL)
        }

        let frameworkPath = frameworkURL.path()
        let libraryPath = "\(outputDir.path())/lib/\(libname).a"
        print("Creating \(frameworkURL.path())\nfrom library at \(libraryPath)")

        let xcodebuild = Process()
        xcodebuild.executableURL = xcodebuildTool.url
        xcodebuild.arguments = [
            "-create-xcframework",
            "-library", libraryPath,
            "-output", frameworkPath,
        ]
        xcodebuild.standardOutput = logFileHandle
        xcodebuild.standardError = logFileHandle
        try xcodebuild.run()
        xcodebuild.waitUntilExit()
        guard xcodebuild.terminationStatus == 0 else {
            throw PluginError(
                "Failed to create \(frameworkURL.path()). See log for details."
            )
        }
        print("Successfully created \(frameworkURL.path())")
        return frameworkURL
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
