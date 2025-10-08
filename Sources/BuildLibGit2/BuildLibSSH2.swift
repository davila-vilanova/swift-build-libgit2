import Foundation
import Dependencies

func buildLibSSH2(target: Target, openSSLTarget: Target) throws {
    @Dependency(\.cloneRepository) var cloneRepository

    let logFileHandle = try prepareBuild(for: target)

    try cloneRepository(
        "https://github.com/libssh2/libssh2.git",
        "libssh2-1.11.1",
        target.sourceDirURL,
    )

    try configureBuild(
        target: target,
        openSSLTarget: openSSLTarget,
        loggingTo: logFileHandle,
    )

    try cmakeBuildAndInstall(
        in: target.buildDirURL,
        loggingTo: logFileHandle
    )

    print("libssh2 library can be found at \(target.installDirURL.path())")
}

private func configureBuild(
    target: Target,
    openSSLTarget: Target,
    loggingTo logFileHandle: FileHandle,
) throws {
    @Dependency(\.urlForTool) var urlForTool

    assert(openSSLTarget.platform == target.platform)
    assert(Set(openSSLTarget.architectures) == Set(target.architectures))

    let cmake = Process()
    cmake.currentDirectoryURL = target.buildDirURL
    cmake.executableURL = try urlForTool("cmake")

    let openSSLLibsDir = openSSLTarget.installDirURL

    let sdkInfo = try getSDKInfo(platform: target.platform)

    cmake.arguments = [
        "-S", target.sourceDirURL.path(),
        "-DCMAKE_OSX_SYSROOT=\(sdkInfo.url.path())",
        "-DCMAKE_SYSTEM_NAME=\(cmakeSystemName(for: target.platform))",
        "-DCMAKE_OSX_ARCHITECTURES:STRING=\(cmakeArchitecturesValue(for: target.architectures))",
        "-DPKG_CONFIG_EXECUTABLE=NO_EXEC",
        "-DCRYPTO_BACKEND=OpenSSL",
        "-DOPENSSL_INCLUDE_DIR=\(openSSLLibsDir.appending(component: "include").path())",
        "-DOPENSSL_SSL_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libssl.a").path())",
        "-DOPENSSL_CRYPTO_LIBRARY=\(openSSLLibsDir.appending(component: "lib").appending(component: "libcrypto.a").path())",
        "-DCMAKE_C_FLAGS=\"-DOPENSSL_NO_ENGINE -Wno-shorten-64-to-32\"",
        "-DENABLE_ZLIB_COMPRESSION=ON",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_INSTALL_PREFIX:PATH=\(target.installDirURL.path())",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_TESTING=OFF",
        "-B", target.buildDirURL.path(),
    ]

    try runProcess(
        cmake, .mergeOutputError(.fileHandle(logFileHandle)), name: "CMake configuration"
    )
}

@discardableResult
func createLibSSH2Framework(targets: [Target]) throws -> URL {
    @Dependency(\.outputDirectoryURL) var outputDirectoryURL

    // at least one target required
    assert(!targets.isEmpty)
    let firstTarget = targets.first!

    let binaries = targets.map {
        $0.installDirURL
            .appending(components: $0.binariesDirRelativePath, $0.libraryName)
            .appendingPathExtension("a")
    }
    let headers = firstTarget.installDirURL
        .appending(path: firstTarget.headersDirRelativePath)

    return try createXCFramework(
        named: firstTarget.libraryName,
        binaries: binaries,
        headers: headers,
        placeInto: outputDirectoryURL
    )
}
