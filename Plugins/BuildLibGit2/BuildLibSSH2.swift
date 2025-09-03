import Foundation
import PackagePlugin

func buildLibSSH2(
    context: PluginContext,
    platform: Platform,
    arguments: [String]
) throws {
    let fileManager = FileManager.default

    // TODO: possibly deduplicate with BuildOpenSSL and BuildLibGit2
    let libsDir = libSSH2LibsDirectoryURL(for: context, platform: platform)
    let logFile = context.pluginWorkDirectoryURL.appending(component: "libssh2_build_\(platform.rawValue).log")
    let buildDir = context.pluginWorkDirectoryURL.appending(component: "libssh2_build_\(platform.rawValue)")

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

    try configureBuild(
        with: context,
        in: buildDir,
        src: srcDir,
        installURL: libsDir,
        loggingTo: logFileHandle,
        platform: platform,
        architecture: .arm64,
        sdkInfo: try getSDKInfo(context: context, platform: platform)
    )

    try buildAndInstall(
        with: context,
        in: buildDir,
        loggingTo: logFileHandle
    )

    print("libssh2 library can be found at \(libsDir.path())")
}

func libSSH2LibsDirectoryURL(
    for context: PluginContext,
    platform: Platform
) -> URL {
    context.pluginWorkDirectoryURL.appending(
        components: "libssh2_libs", libraryDirectoryName(for: platform)
    )
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
    in buildDir: URL,
    src srcDir: URL,
    installURL: URL,
    loggingTo logFileHandle: FileHandle,
    platform: Platform,
    architecture: Architecture,
    sdkInfo: SDKInfo
) throws {
    let cmakeTool = try context.tool(named: "cmake")

    let cmake = Process()
    cmake.currentDirectoryURL = buildDir
    cmake.executableURL = fakeCMakeURL(context) ?? cmakeTool.url

    let openSSLLibsDir = openSSLLibsDirectoryURL(for: context, platform: platform)
    cmake.arguments = [
        "-S", srcDir.path(),
        "-DCMAKE_OSX_SYSROOT=\(sdkInfo.url.path())",
        "-DCMAKE_SYSTEM_NAME=\(cmakeSystemName(for: platform))",
        "-DCMAKE_OSX_ARCHITECTURES:STRING=\(architecture.rawValue)",
        "-DPKG_CONFIG_EXECUTABLE=NO_EXEC",
        "-DCRYPTO_BACKEND=OpenSSL",
        "-DOPENSSL_INCLUDE_DIR=\(openSSLLibsDir.appending(component: "include").path())",
        "-DOPENSSL_SSL_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libssl.a").path())",
        "-DOPENSSL_CRYPTO_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libcrypto.a").path())",
        "-DCMAKE_C_FLAGS=\"-DOPENSSL_NO_ENGINE -Wno-shorten-64-to-32\"",
        "-DENABLE_ZLIB_COMPRESSION=ON",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_INSTALL_PREFIX:PATH=\(installURL.path())",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_TESTING=OFF",
        "-B", buildDir.path(),
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
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    let cmakeTool = try context.tool(named: "cmake")

    let cmake = Process()
    cmake.currentDirectoryURL = buildDir
    cmake.executableURL = fakeCMakeURL(context) ?? cmakeTool.url

    cmake.arguments = [
        "--build", buildDir.path(),
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

@discardableResult
func createLibSSH2Framework(
    with context: PluginContext,
    platforms: [Platform]
) throws -> URL {
    let libLocations = LibraryLocationsByPlatform(
        uniqueKeysWithValues: platforms.map { platform in
            let libDir = libSSH2LibsDirectoryURL(
                for: context,
                platform: platform
            )
            return (
                platform,  // key
                LibraryLocations(  // value
                    binary: libDir.appending(components: "lib", "libssh2.a"),
                    headers: libDir.appending(component: "include")
                )
            )
        }
    )
    return try createXCFramework(
        named: "libssh2",
        with: context,
        fromLibrariesAt: libLocations,
        placeInto: try packageFrameworksDirectory(for: context)
    )
}
