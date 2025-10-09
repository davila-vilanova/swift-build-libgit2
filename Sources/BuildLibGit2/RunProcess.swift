import Dependencies
import Foundation

extension DependencyValues {
    var runProcess: @Sendable (Process, OutputMode) throws -> Void {
        get { self[RunProcessKey.self] }
        set { self[RunProcessKey.self] = newValue }
    }
}

private enum RunProcessKey: DependencyKey {
    static let liveValue: @Sendable (Process, OutputMode) throws -> Void = runProcess
}

/// Runs a child process in the following way:
/// - redirects stdout to a pipe of choice or /dev/null
/// - caches stderr, discards it if the process succeeds, or includes it in thrown exception if it fails
/// - awaits process until it completes
// TODO: rewrite doc
private func runProcess(
    _ process: Process,
    _ outputMode: OutputMode,
) throws {
    if outputMode != .inheritFromProcess {
        process.standardOutput = try outputMode.stdout?.wrappedValue ?? nullFileHandle()
        process.standardError = outputMode.stderr?.wrappedValue
    }
    let processName = process.executableURL?.lastPathComponent ?? "process"

    print("Running \(processName)...")

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let errorMessage =
            if let tempErrorPipe = outputMode.tempErrorPipe {
                String(
                    data: tempErrorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
                    ?? "Unknown error"
            } else {
                "See output for details"
            }

        throw Error("Failed to run \(processName): \(errorMessage).")
    }

    print("\(processName) completed successfully.")
}

enum OutputMode: Equatable {
    case separateOutputError(output: OutputChannel, error: OutputChannel)
    case mergeOutputError(OutputChannel)
    case stdoutOnly(output: OutputChannel, tempError: Pipe)
    case noOutput(tempError: Pipe)
    case inheritFromProcess

    static func stdoutOnly(_ output: OutputChannel) -> OutputMode {
        .stdoutOnly(output: output, tempError: Pipe())
    }

    static func noOutput() -> OutputMode {
        .noOutput(tempError: Pipe())
    }

    var stdout: OutputChannel? {
        switch self {
        case .separateOutputError(output: let ch, _): ch
        case .mergeOutputError(let ch): ch
        case .stdoutOnly(output: let ch, _): ch
        case .noOutput, .inheritFromProcess: nil
        }
    }

    var stderr: OutputChannel? {
        switch self {
        case .separateOutputError(_, error: let ch): ch
        case .mergeOutputError(let ch): ch
        case .stdoutOnly(_, tempError: let pipe): .pipe(pipe)
        case .noOutput(tempError: let pipe): .pipe(pipe)
        case .inheritFromProcess: nil
        }
    }

    var tempErrorPipe: Pipe? {
        switch self {
        case .stdoutOnly(_, tempError: let pipe): pipe
        case .noOutput(tempError: let pipe): pipe
        default: nil
        }
    }
}

enum OutputChannel: Equatable {
    case pipe(Pipe)
    case fileHandle(FileHandle)

    var wrappedValue: Any {
        switch self {
        case .pipe(let value): value
        case .fileHandle(let value): value
        }
    }
}

private func nullFileHandle() throws -> FileHandle {
    // Not caching the file handle so that it's available from all concurrent contexts
    // without incurring in synchronization costs
    guard let nullFileHandle = FileHandle(forWritingAtPath: "/dev/null") else {
        throw Error("Failed to open /dev/null for writing.")
    }
    return nullFileHandle
}
