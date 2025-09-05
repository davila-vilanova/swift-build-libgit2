import Foundation
import PackagePlugin

/// Runs a child process in the following way:
/// - redirects stdout to a pipe of choice or /dev/null
/// - caches stderr, discards it if the process succeeds, or includes it in thrown exception if it fails
/// - awaits process until it completes
// TODO: rewrite doc
@discardableResult
func runProcess(
    _ process: Process,
    _ outputMode: OutputMode,
    name explicitName: String? = nil
) throws -> Process {
    process.standardOutput = try outputMode.stdout?.wrappedValue ?? nullFileHandle()
    process.standardError = outputMode.stderr.wrappedValue
    let processName = explicitName ?? process.executableURL?.lastPathComponent ?? "process"

    print("Running \(processName)...")

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let errorMessage = if let tempErrorPipe = outputMode.tempErrorPipe {
            String(data: tempErrorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
        } else {
            "See output for details"
        }

        throw PluginError("Failed to run \(processName): \(errorMessage).")
    }

    print("\(processName) completed successfully.")
    return process
}

enum OutputMode {
    case separateOutputError(output: OutputChannel, error: OutputChannel)
    case mergeOutputError(OutputChannel)
    case stdoutOnly(output: OutputChannel, tempError: Pipe)
    case noOutput(tempError: Pipe)

    static func stdoutOnly(_ output: OutputChannel) -> OutputMode {
        .stdoutOnly(output: output, tempError: Pipe())
    }

    static func noOutput() -> OutputMode {
        .noOutput(tempError: Pipe())
    }

    var stdout: OutputChannel? {
        switch self {
        case let .separateOutputError(output: ch, _): ch
        case let .mergeOutputError(ch): ch
        case let .stdoutOnly(output: ch, _): ch
        case .noOutput: nil
        }
    }

    var stderr: OutputChannel {
        switch self {
        case let .separateOutputError(_, error: ch): ch
        case let .mergeOutputError(ch): ch
        case let .stdoutOnly(_, tempError: pipe): .pipe(pipe)
        case let .noOutput(tempError: pipe): .pipe(pipe)
        }
    }

    var tempErrorPipe: Pipe? {
        switch self {
        case let .stdoutOnly(_, tempError: pipe): pipe
        case let .noOutput(tempError: pipe): pipe
        default: nil
        }
    }
}

enum OutputChannel {
    case pipe(Pipe)
    case fileHandle(FileHandle)

    var wrappedValue: Any {
        switch self {
        case let .pipe(value): value
        case let .fileHandle(value): value
        }
    }
}

private func nullFileHandle() throws -> FileHandle {
    // Not caching the file handle so that it's available from all concurrent contexts
    // without incurring in synchronization costs
    guard let nullFileHandle = FileHandle(forWritingAtPath: "/dev/null") else {
        throw PluginError("Failed to open /dev/null for writing.")
    }
    return nullFileHandle
}
