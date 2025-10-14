import Foundation
import Dependencies

struct BuildLibGit2 {
    static func build(
        target: Target,
        openSSLTarget: Target,
        libSSH2Target: Target,
    ) throws {
        @Dependency(\.cloneRepository) var cloneRepository
        @Dependency(\.runProcess) var runProcess

        let logFileHandle = try prepareBuild(for: target)

        try cloneRepository(
            "https://github.com/libgit2/libgit2.git",
            "v1.9.1",
            target.sourceDirURL
        )

        try runProcess(
            try createConfigureProcess(
                target: target,
                openSSLTarget: openSSLTarget,
                libSSH2Target: libSSH2Target,
            ),
            .mergeOutputError(.fileHandle(logFileHandle))
        )

        try runProcess(
            try createCmakeBuildAndInstallProcess(in: target.buildDirURL),
            .mergeOutputError(.fileHandle(logFileHandle))
        )
    }

    static func createConfigureProcess(
        target: Target,
        openSSLTarget: Target,
        libSSH2Target: Target,
    ) throws -> Process {
        @Dependency(\.urlForTool) var urlForTool
        @Dependency(\.getSDKInfo) var getSDKInfo

        assert(openSSLTarget.platform == target.platform)
        assert(Set(openSSLTarget.architectures) == Set(target.architectures))

        assert(libSSH2Target.platform == target.platform)
        assert(Set(libSSH2Target.architectures) == Set(target.architectures))

        let cmake = Process()
        cmake.currentDirectoryURL = target.buildDirURL
        cmake.executableURL = try urlForTool("cmake")

        let openSSLLibsDir = openSSLTarget.installDirURL
        let libSSH2LibsDir = libSSH2Target.installDirURL

        let sdkInfo = try getSDKInfo(target.platform)

        cmake.arguments = [
            "-S", target.sourceDirURL.path(),
            "-DCMAKE_OSX_SYSROOT=\(sdkInfo.url.path())",
            "-DCMAKE_SYSTEM_NAME=\(cmakeSystemName(for: target.platform))",
            "-DCMAKE_OSX_ARCHITECTURES:STRING=\(cmakeArchitecturesValue(for: target.architectures))",
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
            "-DCMAKE_INSTALL_PREFIX:PATH=\(target.installDirURL.path())",
            "-DBUILD_TESTS=OFF",
            "-DBUILD_CLI=OFF",
            "-DBUILD_EXAMPLES=OFF",
            "-DBUILD_FUZZERS=OFF",
            "-B", target.buildDirURL.path(),
        ]
        // cmake.environment = [
        //     "OPENSSL_ROOT_DIR": openSSLLibsDir.path()
        // ]
        return cmake
    }

    @discardableResult
    static func createFramework(targets: [Target]) throws -> URL {
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
}
