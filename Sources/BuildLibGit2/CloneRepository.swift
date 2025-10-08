import Dependencies
import Foundation

extension DependencyValues {
    public var cloneRepository: @Sendable (String, String, URL) throws -> Void {
        get { self[CloneRepositoryKey.self] }
        set { self[CloneRepositoryKey.self] = newValue }
    }
}

private enum CloneRepositoryKey: DependencyKey {
    static let liveValue: @Sendable (String, String, URL) throws -> Void = cloneRepository(at:tag:into:)
}

private func cloneRepository(
    at remoteURLString: String,
    tag: String,
    into destinationURL: URL
) throws {
    @Dependency(\.urlForTool) var urlForTool
    @Dependency(\.fileOrDirectoryExists) var fileOrDirectoryExists
    // If the repository already exists in the work directory, we can skip cloning.
    guard !fileOrDirectoryExists(destinationURL) else {
        print("Repository already exists at \(destinationURL.path). Skipping clone.")
        return
    }
    guard
        let remoteURL = URL(string: remoteURLString)
    else {
        throw Error("Invalid repository URL.")
    }

    print("Cloning \(remoteURL) at tag \(tag) into \(destinationURL.path)")
    let gitClone = Process()
    gitClone.executableURL = try urlForTool("git")
    gitClone.arguments = [
        "clone",
        "--branch", tag,
        "--depth", "1",
        "--recurse-submodules",
        "--shallow-submodules",
        remoteURL.absoluteString,
        destinationURL.path,
    ]

    try runProcess(gitClone, .noOutput())

    print("Successfully cloned repository.")
}
