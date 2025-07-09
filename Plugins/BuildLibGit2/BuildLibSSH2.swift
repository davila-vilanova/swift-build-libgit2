import Foundation
import PackagePlugin

func buildLibSSH2(context: PluginContext, arguments: [String]) throws {
    let fileManager = FileManager.default

    // TODO: possibly deduplicate with BuildOpenSSL and BuildLibGit2
    let libsDir = libSSH2LibsDirectoryURL(for: context)
    let logFile = context.pluginWorkDirectoryURL.appending(component: "libssh2_build.log")
    for url in [libsDir, logFile] {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    try fileManager.createDirectory(at: libsDir, withIntermediateDirectories: true)
    fileManager.createFile(atPath: logFile.path, contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    let srcDir = try cloneRepository(with: context)

    try configureBuild(
        with: context,
        in: srcDir,
        installURL: libsDir,
        loggingTo: logFileHandle,
        platform: .iPhoneOS,
        architecture: .arm64,
        sdkInfo: try getSDKInfo(context: context, platform: .iPhoneOS)
    )

    try buildAndInstall(
        with: context,
        in: srcDir,
        loggingTo: logFileHandle
    )

    print("libssh2 library can be found at \(libsDir.path())")

    try createXCFramework(
        named: "libssh2",
        with: context,
        fromLibraryAt: libsDir.appending(component: "lib/libssh2.a"),
        headers: libsDir.appending(component: "include"),
        placeInto: try packageFrameworksDirectory(for: context),
        loggingTo: logFileHandle
    )
}

func libSSH2LibsDirectoryURL(for context: PluginContext) -> URL {
    context.pluginWorkDirectoryURL.appending(component: "libssh2_libs")
}

private func cloneRepository(with context: PluginContext) throws -> URL {
    try cloneRepository(
        at: "https://github.com/libssh2/libssh2.git",
        with: context,
        tag: "libssh2-1.11.1",
        into: "libssh2_src"
    )
}

private func configureBuild(
    with context: PluginContext,
    in srcDir: URL,
    installURL: URL,
    loggingTo logFileHandle: FileHandle,
    platform: Platform,
    architecture: Architecture,
    sdkInfo: SDKInfo
) throws {
    let cmakeTool = try context.tool(named: "cmake")

    let cmake = Process()
    cmake.currentDirectoryURL = srcDir
    cmake.executableURL = cmakeTool.url

    let openSSLLibsDir = openSSLLibsDirectoryURL(for: context)
    cmake.arguments = [
        "-DCMAKE_OSX_SYSROOT=\(sdkInfo.url.path)",
        "-DCMAKE_SYSTEM_NAME=\(systemName(for: platform))",
        "-DCMAKE_OSX_ARCHITECTURES:STRING=\"\(architecture.rawValue)\"",
        "-DPKG_CONFIG_EXECUTABLE=NO_EXEC",
        "-DCRYPTO_BACKEND=OpenSSL",
        "-DOPENSSL_INCLUDE_DIR=\(openSSLLibsDir.appending(component: "include").path)",
        "-DOPENSSL_SSL_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libssl.a").path)",
        "-DOPENSSL_CRYPTO_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libcrypto.a").path)",
        "-DCMAKE_C_FLAGS=\"-DOPENSSL_NO_ENGINE -Wno-shorten-64-to-32\"",
        "-DENABLE_ZLIB_COMPRESSION=ON",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_INSTALL_PREFIX:PATH=\"\(installURL.path)\"",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_TESTING=OFF",
        "-DCMAKE_INSTALL_PREFIX=\(installURL.path)",
        ".",
    ]

    cmake.standardOutput = logFileHandle
    cmake.standardError = logFileHandle
    try cmake.run()
    cmake.waitUntilExit()
    guard cmake.terminationStatus == 0 else {
        throw PluginError("CMake configuration failed. See log for details.")
    }
    print("CMake configuration completed successfully.")
}

private func buildAndInstall(
    with context: PluginContext,
    in srcDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    let cmakeTool = try context.tool(named: "cmake")

    let cmake = Process()
    cmake.currentDirectoryURL = srcDir
    cmake.executableURL = cmakeTool.url

    cmake.arguments = [
        "--build", srcDir.path,
        "--target", "install",
        "--parallel", "\(getSystemCPUCount())",
    ]

    cmake.standardOutput = logFileHandle
    cmake.standardError = logFileHandle
    try cmake.run()
    cmake.waitUntilExit()
    guard cmake.terminationStatus == 0 else {
        throw PluginError("CMake build failed. See log for details.")
    }
}
