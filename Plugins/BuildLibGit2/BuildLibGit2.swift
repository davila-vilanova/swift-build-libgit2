import Foundation
import PackagePlugin

func buildLibGit2(
    context: PluginContext,
    platform: Platform,
    arguments: [String]
) throws {
    let architecture = Architecture.arm64

    let fileManager = FileManager.default
    let libsDir = libGit2LibsDirectoryURL(for: context, platform: platform)
    let logFile = context.pluginWorkDirectoryURL.appending(component: "libgit2_build_\(platform.rawValue).log")
    let buildDir = context.pluginWorkDirectoryURL.appending(component: "libgit2_build_\(platform.rawValue)_\(architecture.rawValue)")

    for url in [libsDir, buildDir, logFile] {
        if fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }

    for dir in [libsDir, buildDir] {
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
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
        architecture: architecture,
        sdkInfo: try getSDKInfo(context: context, platform: platform)
    )

    try buildAndInstall(
        with: context,
        in: buildDir,
        loggingTo: logFileHandle
    )
}

func libGit2LibsDirectoryURL(
    for context: PluginContext,
    platform: Platform
) -> URL {
    context.pluginWorkDirectoryURL.appending(
        components: "libgit2_libs", libraryDirectoryName(for: platform)
    )
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

    let libSSH2LibsDir = libSSH2LibsDirectoryURL(for: context, platform: platform)
    let openSSLLibsDir = openSSLLibsDirectoryURL(for: context, platform: platform)

    cmake.arguments = [
        "-S", srcDir.path(),
        "-DCMAKE_OSX_SYSROOT=\(sdkInfo.url.path())",
        "-DCMAKE_SYSTEM_NAME=\(cmakeSystemName(for: platform))",
        "-DCMAKE_OSX_ARCHITECTURES:STRING=\(architecture.rawValue)",
        "-DCMAKE_C_COMPILER_WORKS:BOOL=ON",
        "-DPKG_CONFIG_EXECUTABLE=NO_EXEC",
        "-DPKG_CONFIG_USE_CMAKE_PREFIX_PATH:BOOL=ON",
        "-DUSE_SSH=ON",
        "-DLIBSSH2_LIBRARY=\(libSSH2LibsDir.appending(components: "lib", "libssh2.a").path())",
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
        "-B", buildDir.path(),
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
    print("cmake command: \ncmake \(cmake.arguments!.joined(separator: " "))")

    cmake.standardOutput = logFileHandle
    cmake.standardError = logFileHandle
    try cmake.run()
    cmake.waitUntilExit()
    guard cmake.terminationStatus == 0 else {
        throw PluginError("CMake build failed. See log for details.")
    }
}

@discardableResult
func createLibGit2Framework(
    with context: PluginContext,
    platforms: [Platform]
) throws -> URL {
    let libLocations = LibraryLocationsByPlatform(
        uniqueKeysWithValues: platforms.map { platform in
            let libDir = libGit2LibsDirectoryURL(
                for: context,
                platform: platform
            )
            return (
                platform,  // key
                LibraryLocations(  // value
                    binary: libDir.appending(components: "lib", "libgit2.a"),
                    headers: libDir.appending(component: "include")
                                )
            )
        }
    )
    let frameworkURL = try createXCFramework(
        named: "libgit2",
        with: context,
        fromLibrariesAt: libLocations,
        placeInto: try packageFrameworksDirectory(for: context)
    )

    for platform in libLocations.keys {
        try writeModuleMap(
            inFrameworkAt: frameworkURL, platform: platform, architecture: .arm64
        )
    }

    return frameworkURL
}
