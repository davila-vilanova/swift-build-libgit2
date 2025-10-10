import Foundation

@testable import BuildLibGit2

final class SideEffectsTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _actions = [String]()

    var actions: [String] {
        lock.withLock { _actions }
    }

    func createDirectories(_ urls: URL...) {
        lock.withLock {
            _actions.append(
                "create directories \(urls.map { $0.path() }.joined(separator: ", "))"
            )
        }
    }

    func copyFileOrDirectory(from src: URL, to dst: URL) {
        lock.withLock {
            _actions.append("copy \(src.path()) to \(dst.path())")
        }
    }

    func removeFileOrDirectory(_ url: URL) throws {
        lock.withLock {
            _actions.append("remove \(url.path())")
        }
    }

    func runProcess(_ process: Process, _: OutputMode) {
        lock.withLock {
            _actions.append(
                "run process \(process.testDescription)")
        }
    }
}

extension Process {
    fileprivate var testDescription: String {
        "\(executableURL?.path() ?? "no executable") "
            + "\((arguments?.joined(separator: " ") ?? "no arguments"))"
    }
}
