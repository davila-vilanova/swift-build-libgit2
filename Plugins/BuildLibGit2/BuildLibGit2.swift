import Foundation
import PackagePlugin

func buildLibGit2(
    context: PluginContext,
    platform: Platform,
    arguments: [String]
) throws {
    let architecture = Architecture.arm64

    let (buildURLs, logFileHandle) = try prepareBuild(
        libraryName: "libgit2",
        getInstallDir: libGit2LibsDirectoryURL,
        context: context,
        platform: platform,
        arguments: arguments,
        cloneRepository: cloneRepository,
    )


    try configureBuild(
        with: context,
        urls: buildURLs,
        loggingTo: logFileHandle,
        platform: platform,
        architecture: architecture,
        sdkInfo: try getSDKInfo(context: context, platform: platform)
    )

    try buildAndInstall(
        with: context,
        in: buildURLs.build,
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
    urls: BuildURLs,
    loggingTo logFileHandle: FileHandle,
    platform: Platform,
    architecture: Architecture,
    sdkInfo: SDKInfo
) throws {
    let cmakeTool = try context.tool(named: "cmake")

    let cmake = Process()
    cmake.currentDirectoryURL = urls.build
    cmake.executableURL = fakeCMakeURL(context) ?? cmakeTool.url

    let libSSH2LibsDir = libSSH2LibsDirectoryURL(for: context, platform: platform)
    let openSSLLibsDir = openSSLLibsDirectoryURL(for: context, platform: platform)

    cmake.arguments = [
        "-S", urls.source.path(),
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
        "-DCMAKE_INSTALL_PREFIX:PATH=\(urls.install.path())",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_CLI=OFF",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_FUZZERS=OFF",
        "-B", urls.build.path(),
    ]
    // cmake.environment = [
    //     "OPENSSL_ROOT_DIR": openSSLLibsDir.path()
    // ]

    try runProcess(
        cmake, .mergeOutputError(.fileHandle(logFileHandle)), name: "CMake configuration"
    )
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

    try runProcess(
        cmake, .mergeOutputError(.fileHandle(logFileHandle)), name: "CMake build"
    )
}

@discardableResult
func createLibGit2Framework(
    with context: PluginContext,
    platforms: [Platform]
) throws -> URL {
    assert (!platforms.isEmpty)
    let (binaries, headers) = locationsForPlatforms(
        platforms,
        libraryName: "libgit2",
        findLibraryDir: libGit2LibsDirectoryURL,
        context: context)

    let frameworkURL = try createXCFramework(
        named: "libgit2",
        with: context,
        binaries: binaries,
        headers: headers,
        placeInto: try packageFrameworksDirectory(for: context)
    )

    for platform in platforms {
        try writeModuleMap(
            inFrameworkAt: frameworkURL, platform: platform, architecture: .arm64
        )
    }

    return frameworkURL
}
