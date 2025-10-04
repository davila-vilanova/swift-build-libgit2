import Foundation
import PackagePlugin

func prepareBuild(
    libraryName: String,
    getInstallDir: (PluginContext, Platform) -> URL,
    context: PluginContext,
    platform: Platform,
    arguments: [String],
    cloneRepository: (PluginContext) throws -> URL,
) throws -> (BuildURLs, FileHandle) {
    try checkValidLibraryName(libraryName)

    let fileManager = FileManager.default

    let installDir = getInstallDir(context, platform)

    let buildDir = context.pluginWorkDirectoryURL
        .appending(component: "\(libraryName)_build_\(platform.rawValue)")

    for dir in [installDir, buildDir] {
        if fileManager.fileExists(atPath: dir.path()) {
            try fileManager.removeItem(at: dir)
        }
        try fileManager.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    let logFile = buildDir.appending(
        component: "build_\(platform.rawValue).log"
    )
    fileManager.createFile(atPath: logFile.path(), contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    let srcDir = try cloneRepository(context)

    let urls = BuildURLs(
        source: srcDir,
        build: buildDir,
        log: logFile,
        install: installDir
    )

    return (urls, logFileHandle)
}

struct BuildURLs {
    let source: URL
    let build: URL
    let log: URL
    let install: URL
}

private func checkValidLibraryName(_ filename: String) throws {
    if filename.isEmpty {
        throw InvalidLibraryNameError(filename: filename)
    }
    // TODO: check suitable for part of filename
}

struct InvalidLibraryNameError: Error {
    let filename: String
}
