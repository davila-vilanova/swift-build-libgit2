import Foundation

func prepareBuild(for target: Target) throws -> FileHandle {
    try checkValidLibraryName(target.libraryName)

    let fileManager = FileManager.default

    for dir in [target.installDirURL, target.buildDirURL] {
        if fileManager.fileExists(atPath: dir.path()) {
            try fileManager.removeItem(at: dir)
        }
        try fileManager.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    let logFile = target.buildDirURL.appending(component: "build").appendingPathExtension("log")
    fileManager.createFile(atPath: logFile.path(), contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    return logFileHandle
}

private func checkValidLibraryName(_ filename: String) throws {
    if filename.isEmpty {
        throw InvalidLibraryNameError(filename: filename)
    }
    // TODO: check suitable for part of filename
}

struct InvalidLibraryNameError: Swift.Error {
    let filename: String
}
