import Dependencies
import Foundation

extension DependencyValues {
    public var urlForTool: @Sendable (String) throws -> URL {
        get { self[URLForToolKey.self] }
        set { self[URLForToolKey.self] = newValue }
    }
}

private enum URLForToolKey: DependencyKey {
    static var liveValue: @Sendable (String) throws -> URL {
        return { toolName in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [toolName]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw Error("Tool '\(toolName)' not found")
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
    }
}

