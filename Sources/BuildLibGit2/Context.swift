import Foundation

class Context {
    let workDirectoryURL: URL
    let outputDirectoryURL: URL

    func urlForTool(named: String) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [named]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Error("Tool '\(named)' not found")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines)
        else {
            throw Error("Failed to read tool path")
        }

        return URL(fileURLWithPath: output)
    }

    init(workDirectoryURL: URL, outputFrameworksDirectoryURL: URL) {
        self.workDirectoryURL = workDirectoryURL
        self.outputDirectoryURL = outputFrameworksDirectoryURL
    }
}
