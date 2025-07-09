import Foundation
import PackagePlugin

func buildLibGit2(context: PluginContext, arguments: [String]) throws {
    let platform = Platform.iPhoneOS
    let architecture = Architecture.arm64

    let fileManager = FileManager.default
    let libsDir = libGit2LibsDirectoryURL(for: context)
    let logFile = context.pluginWorkDirectoryURL.appending(component: "libgit2_build.log")
    for url in [libsDir, logFile] {
        if fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }
    try fileManager.createDirectory(at: libsDir, withIntermediateDirectories: true)
    fileManager.createFile(atPath: logFile.path(), contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    let srcDir = try cloneRepository(with: context)

    try configureBuild(
        with: context,
        in: srcDir,
        installURL: libsDir,
        loggingTo: logFileHandle,
        platform: platform,
        architecture: architecture,
        sdkInfo: try getSDKInfo(context: context, platform: platform)
    )

    try buildAndInstall(
        with: context,
        in: srcDir,
        loggingTo: logFileHandle
    )

    let frameworkURL = try createXCFramework(
        named: "libgit2",
        with: context,
        fromLibraryAt: libsDir.appending(component: "lib/libgit2.a"),
        headers: libsDir.appending(component: "include"),
        placeInto: try packageFrameworksDirectory(for: context),
        loggingTo: logFileHandle
    )

    try writeModuleMap(inFrameworkAt: frameworkURL, platform: platform, architecture: architecture)
}

func libGit2LibsDirectoryURL(for context: PluginContext) -> URL {
    context.pluginWorkDirectoryURL.appending(component: "libgit2_libs")
}

private func cloneRepository(with context: PluginContext) throws -> URL {
    try cloneRepository(
        at: "https://github.com/libgit2/libgit2.git",
        with: context,
        tag: "v1.9.1",
        into: "libgit2_src"
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

    let libSSH2LibsDir = libSSH2LibsDirectoryURL(for: context)
    let openSSLLibsDir = openSSLLibsDirectoryURL(for: context)
    print("Using OpenSSL libs at \(openSSLLibsDir.path())")
    cmake.arguments = [
        "-DCMAKE_OSX_SYSROOT=\(sdkInfo.url.path())",
        "-DCMAKE_SYSTEM_NAME=\(systemName(for: platform))",
        "-DCMAKE_OSX_ARCHITECTURES:STRING=\(architecture.rawValue)",
        "-DCMAKE_C_COMPILER_WORKS:BOOL=ON",
        "-DPKG_CONFIG_EXECUTABLE=NO_EXEC",
        "-DPKG_CONFIG_USE_CMAKE_PREFIX_PATH:BOOL=ON",
        "-DUSE_SSH=ON",
        "-DLIBSSH2_LIBRARY=\(libSSH2LibsDir.appending(component: "lib").appending(component: "libssh2.a").path())",
        "-DLIBSSH2_INCLUDE_DIR=\(libSSH2LibsDir.appending(component: "include").path())",
        "-DLIBSSH2_LDFLAGS=-lssh2",
        "-DHAVE_LIBSSH2_MEMORY_CREDENTIALS=ON",
        "-DOPENSSL_ROOT_DIR=\(openSSLLibsDir.path())",
        "-DOPENSSL_INCLUDE_DIR=\(openSSLLibsDir.path())/include",
        "-DOPENSSL_SSL_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libssl.a").path())",
        "-DOPENSSL_CRYPTO_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libcrypto.a").path())",
        "-DBUILD_SHARED_LIBS:BOOL=OFF",
        "-DCMAKE_INSTALL_PREFIX:PATH=\(installURL.path())",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_CLI=OFF",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_FUZZERS=OFF",
        "\(srcDir.path())",
    ]
    // cmake.environment = [
    //     "OPENSSL_ROOT_DIR": openSSLLibsDir.path()
    // ]

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
        "--build", srcDir.path(),
        "--target", "install",
        "--parallel", "\(getSystemCPUCount())",
    ]
    print("cmake command: \ncmake \(cmake.arguments!.joined(separator: " "))")

    cmake.standardOutput = logFileHandle
    cmake.standardError = logFileHandle
    try cmake.run()
    cmake.waitUntilExit()
    guard cmake.terminationStatus == 0 else {
        throw PluginError("CMake build failed. See log for details.")
    }
}
