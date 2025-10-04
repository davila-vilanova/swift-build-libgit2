import Foundation

func cloneRepository(
    at remoteURLString: String,
    with context: Context,
    tag: String,
    into destinationURL: URL
) throws {
    // If the repository already exists in the work directory, we can skip cloning.
    guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
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
    gitClone.executableURL = try context.urlForTool(named: "git")
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
