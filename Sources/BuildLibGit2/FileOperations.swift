import Dependencies
import Foundation

extension DependencyValues {
    /// Deletes the directory if it exists previous to creating it
    public var createDirectories: @Sendable (URL...) throws -> Void {
        get { self[CreateDirectoriesKey.self] }
        set { self[CreateDirectoriesKey.self] = newValue }
    }

    public var copyFileOrDirectory: @Sendable (URL, URL) throws -> Void {
        get { self[CopyFileOrDirectoryKey.self] }
        set { self[CopyFileOrDirectoryKey.self] = newValue }
    }

    public var fileOrDirectoryExists: @Sendable (URL) -> Bool {
        get { self[FileExistsKey.self] }
        set { self[FileExistsKey.self] = newValue }
    }

    public var removeFileOrDirectory: @Sendable (URL) throws -> Void {
        get { self[RemoveFileOrDirectoryKey.self] }
        set { self[RemoveFileOrDirectoryKey.self] = newValue }
    }

    public var createFile: @Sendable (URL) throws -> Void {
        get { self[CreateFileKey.self] }
        set { self[CreateFileKey.self] = newValue }
    }
}

private enum CreateDirectoriesKey: DependencyKey {
    static let liveValue: @Sendable (URL...) throws -> Void = { urls in
        for url in urls {
            try createDirectory(at: url)
        }
    }
}

private enum CreateFileKey: DependencyKey {
    static let liveValue: @Sendable (URL) throws -> Void = createFile(at:)
}

private enum CopyFileOrDirectoryKey: DependencyKey {
    static let liveValue: @Sendable (URL, URL) throws -> Void = {
        try FileManager.default.copyItem(at: $0, to: $1)
    }
}

private enum FileExistsKey: DependencyKey {
    static let liveValue: @Sendable (URL) -> Bool = fileExists(at:)
}

private enum RemoveFileOrDirectoryKey: DependencyKey {
    static let liveValue: @Sendable (URL) throws -> Void = removeFileOrDirectory(at:)
}

private func createDirectory(at url: URL) throws {
    try removeFileOrDirectory(at: url)
    try FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: true
    )
}

private func createFile(at url: URL) throws {
    try removeFileOrDirectory(at: url)
    FileManager.default.createFile(atPath: url.path(), contents: Data())
}

private func fileExists(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path())
}

private func removeFileOrDirectory(at url: URL) throws {
    if fileExists(at: url) {
        try FileManager.default.removeItem(at: url)
    }
}
