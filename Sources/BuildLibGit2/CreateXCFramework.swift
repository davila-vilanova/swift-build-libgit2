import Dependencies
import Foundation

@discardableResult
func createXCFramework(
    named frameworkName: String,
    binaries: [URL],
    headers: URL,
    placeInto frameworksDir: URL,
) throws -> URL {
    @Dependency(\.urlForTool) var urlForTool
    @Dependency(\.removeFileOrDirectory) var removeDirectory
    @Dependency(\.runProcess) var runProcess

    let frameworkURL = frameworksDir.appending(component: "\(frameworkName).xcframework")
    try removeDirectory(frameworkURL)

    let frameworkPath = frameworkURL.path()
    print("Creating \(frameworkURL.path())\nfrom binaries at \(binaries)")

    let xcodebuild = Process()
    xcodebuild.executableURL = try urlForTool("xcodebuild")
    xcodebuild.arguments =
        ["-create-xcframework"]
        + libraryArguments(binaries: binaries, headers: headers)
        + ["-output", frameworkPath]

    try runProcess(xcodebuild, .noOutput())

    return frameworkURL
}

//func createXCFramework(
//    name: String,
//    // this library will be either a single arch for a single platform or a fat binary for a single platform
//    findLibraryDir: (Platform) -> URL,
//    context: Context,
//    platforms: [Platform]
//) throws -> URL {
//    assert(!platforms.isEmpty)
//
//    let (binaries, headers) = locationsForPlatforms(
//        platforms,
//        libraryName: name,
//        findLibraryDir: findLibraryDir,
//    )
//
//    return try createXCFramework(
//        named: name,
//        with: context,
//        binaries: binaries,
//        headers: headers,
//        placeInto: try packageFrameworksDirectory(for: context)
//    )
//}

/// Takes
/// - an array of URLs, each pointing to a library binary for a different platform (or architecture?)
/// - a URL pointing to the headers directory for the library
///
/// Returns a list of arguments like
/// ```[
///    "-library",
///    "products/iOS/usr/local/lib/libMyLibrary.a",
///    "-headers",
///    "products/iOS/usr/local/include",
///    "-library",
///    "products/iOS_Simulator/usr/local/lib/libMyLibrary.a",
///    "-headers",
///    "products/iOS/usr/local/include"
/// ]```
private func libraryArguments(binaries: [URL], headers: URL) -> [String] {
    binaries.flatMap { binary in
        [
            "-library",
            binary.path(),
            "-headers",
            headers.path(),
        ]
    }
}

// func packageFrameworksDirectory() throws -> URL {
//     @Dependency(\.outputDirectoryURL) var outputDirectoryURL

//     let frameworksDir = outputDirectoryURL.appending(component: "Frameworks")
//     if !FileManager.default.fileExists(atPath: frameworksDir.path) {
//         try FileManager.default.createDirectory(
//             at: frameworksDir,
//             withIntermediateDirectories: true
//         )
//     }
//     return frameworksDir
// }
