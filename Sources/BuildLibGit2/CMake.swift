import Dependencies
import Foundation

func cmakeBuildAndInstall(
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws {
    @Dependency(\.urlForTool) var urlForTool

    let cmake = Process()
    cmake.currentDirectoryURL = buildDir
    cmake.executableURL = try urlForTool("cmake")

    cmake.arguments = [
        "--build", buildDir.path(),
        "--target", "install",
        "--parallel", "\(getSystemCPUCount())",
    ]

    try runProcess(
        cmake, .mergeOutputError(.fileHandle(logFileHandle)), name: "CMake build"
    )
}
