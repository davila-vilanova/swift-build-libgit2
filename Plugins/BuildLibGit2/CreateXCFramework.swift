import Foundation
import PackagePlugin

@discardableResult
func createXCFramework(
    named frameworkName: String,
    with context: PluginContext,
    fromLibrariesAt libLocations: LibraryLocationsByPlatform,
    placeInto frameworksDir: URL,
) throws -> URL {
    let xcodebuildTool = try context.tool(named: "xcodebuild")

    let frameworkURL = frameworksDir.appending(component: "\(frameworkName).xcframework")
    if FileManager.default.fileExists(atPath: frameworkURL.path) {
        try FileManager.default.removeItem(at: frameworkURL)
    }

    let frameworkPath = frameworkURL.path()
    print(" Creating \(frameworkURL.path())\nfrom libraries at \(libLocations)")

    let xcodebuild = Process()
    xcodebuild.executableURL = fakeXcodeBuildURL(context) ?? xcodebuildTool.url
    xcodebuild.arguments =
        ["-create-xcframework"]
        + libLocations.flatMap { (platform, locations) in
            [
                "-library", locations.binary.path(),
//                "-headers", locations.headers.path(),
            ] + {
                if let headers = locations.headers {
                    ["-headers", headers.path(),]
                } else {
                    []
                }
            }()
        }
        + ["-output", frameworkPath]

    try xcodebuild.run()
    xcodebuild.waitUntilExit()
    guard xcodebuild.terminationStatus == 0 else {
        throw PluginError(
            "Failed to create \(frameworkURL.path())."
        )
    }
    print("Successfully created \(frameworkURL.path())")
    return frameworkURL
}

func packageFrameworksDirectory(
    for context: PluginContext
) throws -> URL {
    let frameworksDir = context.package.directoryURL.appending(component: "Frameworks")
    if !FileManager.default.fileExists(atPath: frameworksDir.path) {
        try FileManager.default.createDirectory(
            at: frameworksDir,
            withIntermediateDirectories: true
        )
    }
    return frameworksDir
}

struct LibraryLocations {
    let binary: URL
    let headers: URL?
}

typealias LibraryLocationsByPlatform = [Platform: LibraryLocations]
