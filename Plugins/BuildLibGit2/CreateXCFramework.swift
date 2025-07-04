import Foundation
import PackagePlugin

@discardableResult
func createXCFramework(
    named frameworkName: String,
    with context: PluginContext,
    fromLibraryAt libraryPath: URL,
    headers: URL? = nil,
    placeInto frameworksDir: URL,
    loggingTo logFileHandle: FileHandle
) throws -> URL {
    let xcodebuildTool = try context.tool(named: "xcodebuild")

    let frameworkURL = frameworksDir.appending(component: "\(frameworkName).xcframework")
    if FileManager.default.fileExists(atPath: frameworkURL.path) {
        try FileManager.default.removeItem(at: frameworkURL)
    }

    let frameworkPath = frameworkURL.path()
    print(" Creating \(frameworkURL.path())\nfrom library at \(libraryPath.path())")

    let xcodebuild = Process()
    xcodebuild.executableURL = xcodebuildTool.url
    xcodebuild.arguments =
        [
            "-create-xcframework",
            "-library", libraryPath.path(),
        ] + (headers.map { ["-headers", "\($0.path())"] } ?? [])
        + [
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

func packageFrameworksDirectory(
    for context: PluginContext
) throws -> URL {
    let frameworksDir = context.package.directoryURL.appending(component: "frameworks")
    if !FileManager.default.fileExists(atPath: frameworksDir.path) {
        try FileManager.default.createDirectory(
            at: frameworksDir,
            withIntermediateDirectories: true
        )
    }
    return frameworksDir
}
