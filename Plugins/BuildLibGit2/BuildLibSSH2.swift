import Foundation
import PackagePlugin

func buildLibSSH2(
    context: PluginContext,
    platform: Platform,
    architectures: [Architecture],
    arguments: [String]
) throws {
    let (buildURLs, logFileHandle) = try prepareBuild(
        libraryName: "libssh2",
        getInstallDir: libSSH2LibsDirectoryURL,
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
        architectures: architectures,
        sdkInfo: try getSDKInfo(context: context, platform: platform)
    )

    try buildAndInstall(
        with: context,
        in: buildURLs.build,
        loggingTo: logFileHandle
    )

    print("libssh2 library can be found at \(buildURLs.install.path())")
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
    urls: BuildURLs,
    loggingTo logFileHandle: FileHandle,
    platform: Platform,
    architectures: [Architecture],
    sdkInfo: SDKInfo
) throws {
    let cmakeTool = try context.tool(named: "cmake")

    let cmake = Process()
    cmake.currentDirectoryURL = urls.build
    cmake.executableURL = fakeCMakeURL(context) ?? cmakeTool.url

    let openSSLLibsDir = openSSLLibsDirectoryURL(for: context, platform: platform)

    cmake.arguments = [
        "-S", urls.source.path(),
        "-DCMAKE_OSX_SYSROOT=\(sdkInfo.url.path())",
        "-DCMAKE_SYSTEM_NAME=\(cmakeSystemName(for: platform))",
        "-DCMAKE_OSX_ARCHITECTURES:STRING=\(cmakeArchitecturesValue(for: architectures))",
        "-DPKG_CONFIG_EXECUTABLE=NO_EXEC",
        "-DCRYPTO_BACKEND=OpenSSL",
        "-DOPENSSL_INCLUDE_DIR=\(openSSLLibsDir.appending(component: "include").path())",
        "-DOPENSSL_SSL_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libssl.a").path())",
        "-DOPENSSL_CRYPTO_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libcrypto.a").path())",
        "-DCMAKE_C_FLAGS=\"-DOPENSSL_NO_ENGINE -Wno-shorten-64-to-32\"",
        "-DENABLE_ZLIB_COMPRESSION=ON",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_INSTALL_PREFIX:PATH=\(urls.install.path())",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_TESTING=OFF",
        "-B", urls.build.path(),
    ]

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
func createLibSSH2Framework(
    with context: PluginContext,
    platforms: [Platform]
) throws -> URL {
    try createXCFramework(
        name: "libssh2",
        findLibraryDir: libSSH2LibsDirectoryURL,
        context: context,
        platforms: platforms)
}
