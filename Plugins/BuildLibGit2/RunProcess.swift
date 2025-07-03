import Foundation
import PackagePlugin

/// Runs a child process in the following way:
/// - redirects stdout to a pipe of choice or /dev/null
/// - caches stderr, discards it if the process succeeds, or prints it if it fails
/// - await process until it completes
/// TODO: rename
@discardableResult
func runProcess(_ process: Process, stdout: Pipe? = nil) throws -> Process {
    let errorPipe = Pipe()

    if let stdout = stdout {
        process.standardOutput = stdout
    } else {
        process.standardOutput = try getNullFileHandle()
    }
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw PluginError("Failed to clone OpenSSL repository: \(errorMessage)")
    }
    return process
}

private func getNullFileHandle() throws -> FileHandle {
    // Not caching the file handle so that it's available from all concurrent contexts
    // without incurring in synchronization costs
    guard let nullFileHandle = FileHandle(forWritingAtPath: "/dev/null") else {
        throw PluginError("Failed to open /dev/null for writing.")
    }
    return nullFileHandle
}
