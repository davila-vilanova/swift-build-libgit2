import Dependencies
import Foundation

func createCmakeBuildAndInstallProcess(
    in buildDir: URL,
    loggingTo logFileHandle: FileHandle
) throws -> Process {
    @Dependency(\.urlForTool) var urlForTool
    @Dependency(\.systemCPUCount) var systemCPUCount

    let cmake = Process()
    cmake.currentDirectoryURL = buildDir
    cmake.executableURL = try urlForTool("cmake")

    cmake.arguments = [
        "--build", buildDir.path(),
        "--target", "install",
        "--parallel", "\(systemCPUCount)",
    ]
    return cmake
}
