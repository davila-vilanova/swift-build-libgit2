import Foundation
import Dependencies

extension DependencyValues {
    /// A dependency that produces the work directory URL.
    public var workDirectoryURL: URL {
        get { self[WorkDirectoryURLKey.self] }
        set { self[WorkDirectoryURLKey.self] = newValue }
    }

    public var outputDirectoryURL: URL {
        get { self[OutputDirectoryURLKey.self] }
        set { self[OutputDirectoryURLKey.self] = newValue }
    }
}

private enum WorkDirectoryURLKey: DependencyKey {
    static var liveValue: URL {
        fatalError("Work directory URL has not been set")
    }
}

private enum OutputDirectoryURLKey: DependencyKey {
    static var liveValue: URL {
        fatalError("Output directory URL has not been set")
    }
}

