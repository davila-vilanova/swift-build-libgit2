import Foundation
import PackagePlugin

func buildOpenSSL(
    context: PluginContext,
    platform: Platform,
    arguments: [String]
) throws {
    let (buildURLs, logFileHandle) = try prepareBuild(
        libraryName: "openssl",
        getInstallDir: openSSLLibsDirectoryURL,
        context: context,
        platform: platform,
        arguments: arguments,
        cloneRepository: cloneRepository,
    )

    try configureBuild(
        with: context,
        for: platform,
        urls: buildURLs,
        loggingTo: logFileHandle
    )
    try runMake(
        with: context,
        in: buildURLs.build,
        loggingTo: logFileHandle
    )
    try runMakeInstall(
        with: context,
        in: buildURLs.build,
        loggingTo: logFileHandle
    )

    print("OpenSSL libraries for \(platform.rawValue) can be found at \(buildURLs.install.path())")
}

func openSSLLibsDirectoryURL(
    for context: PluginContext,
    platform: Platform
) -> URL {
    context.pluginWorkDirectoryURL.appending(
        components: "openssl_libs", libraryDirectoryName(for: platform)
    )
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
    for platform: Platform,
    urls: BuildURLs,
    loggingTo logFileHandle: FileHandle,
) throws {
    let configure = Process()
    configure.currentDirectoryURL = urls.build
    configure.executableURL =
        fakeConfigureURL(context) ?? urls.source.appending(component: "Configure")

    // TODO: support for different archs
    // supported:
    // ios64-xcrun
    // iossimulator-arm64-xcrun
    // darwin64-arm64
    //
    // missing:
    // iossimulator-x86_64-xcrun
    // darwin64-x86_64

    let platformArgs =
        switch platform {
        case .iPhoneOS: ["ios64-xcrun"]
        case .iPhoneSimulator: ["iossimulator-arm64-xcrun"]
        case .macOS: ["darwin64-arm64"]
        }

    configure.arguments =
        platformArgs + [
            "no-shared",
            "no-dso",
            "no-apps",
            "no-docs",
            "no-ui-console",
            "zlib",
            "--prefix=\(urls.install.path(percentEncoded: true))",
        ]

    try runProcess(configure, .mergeOutputError(.fileHandle(logFileHandle)))
}

private func runMake(
    with context: PluginContext,
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    let makeTool = try context.tool(named: "make")

    let make = Process()
    make.currentDirectoryURL = buildDir
    make.executableURL = fakeMakeURL(context) ?? makeTool.url
    make.arguments = [
        "-j", "\(getSystemCPUCount())",
        "build_libs",
    ]
    try runProcess(make, .mergeOutputError(.fileHandle(logFileHandle)))
}

private func runMakeInstall(
    with context: PluginContext,
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    let makeTool = try context.tool(named: "make")

    let makeInstall = Process()
    makeInstall.currentDirectoryURL = buildDir
    makeInstall.executableURL = fakeMakeURL(context) ?? makeTool.url
    makeInstall.arguments = ["install_sw"]
    try runProcess(
        makeInstall,
        .mergeOutputError(.fileHandle(logFileHandle)),
        name: "make install_sw")
}

@discardableResult
func createOpenSSLXCFrameworks(
    with context: PluginContext,
    platforms: [Platform]
) throws -> [URL] {
    try ["libssl", "libcrypto"].map { libname in
        try createXCFramework(
            name: libname,
            findLibraryDir: openSSLLibsDirectoryURL,
            context: context,
            platforms: platforms)
    }
}


