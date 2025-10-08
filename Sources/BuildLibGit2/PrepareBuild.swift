import Dependencies
import Foundation

func prepareBuild(for target: Target) throws -> FileHandle {
    @Dependency(\.createDirectories) var createDirectories
    @Dependency(\.createFile) var createFile

    try checkValidLibraryName(target.libraryName)

    try createDirectories(target.installDirURL, target.buildDirURL)

    let logFile = target.buildDirURL.appending(component: "build").appendingPathExtension("log")
    try createFile(logFile)
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
