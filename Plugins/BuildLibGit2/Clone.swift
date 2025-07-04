import Foundation
import PackagePlugin

func cloneRepository(
    at remoteURLString: String,
    with context: PluginContext,
    tag: String,
    into directoryName: String
) throws -> URL {
    let gitTool = try context.tool(named: "git")

    // If the OpenSSL repository already exists in the work directory, we can skip cloning.
    let localURL = context.pluginWorkDirectoryURL.appending(component: directoryName)
    guard !FileManager.default.fileExists(atPath: localURL.path) else {
        print("Repository already exists at \(localURL.path). Skipping clone.")
        return localURL
    }
    guard
        let remoteURL = URL(string: remoteURLString)
    else {
        throw PluginError("Invalid repository URL.")
    }

    print("Cloning \(remoteURL) at tag \(tag) into \(localURL.path)")
    let gitClone = Process()
    gitClone.executableURL = gitTool.url
    gitClone.arguments = [
        "clone",
        "--branch", tag,
        "--depth", "1",
        "--recurse-submodules",
        "--shallow-submodules",
        remoteURL.absoluteString,
        localURL.path,
    ]

    try runProcess(gitClone)

    print("Successfully cloned repository.")
    return localURL
}
