import Dependencies
import Foundation

func getSystemCPUCount() -> Int {
    return ProcessInfo.processInfo.processorCount
}

struct SDKInfo {
    let version: String
    let url: URL
}

func getSDKInfo(platform: Platform) throws -> SDKInfo {
    let xcodebuildOutput = try runToolForOutput(
        tool: "xcodebuild",
        arguments: ["-version", "-sdk", sdkName(for: platform)],
    )
    .split(separator: "\n")

    let versionLine =
        xcodebuildOutput.first(where: { $0.starts(with: "SDKVersion") })
    let pathLine =
        xcodebuildOutput.first(where: { $0.starts(with: "Path") })

    guard let version = versionLine?.split(separator: " ").last else {
        throw Error("Failed to find SDK version in xcodebuild output")
    }
    guard let path = pathLine?.split(separator: " ").last else {
        throw Error("Failed to find SDK path in xcodebuild output")
    }
    guard let url = URL(string: String(path)) else {
        throw Error("Invalid SDK path: \(path)")
    }
    return SDKInfo(version: String(version), url: url)
}

private func runToolForOutput(
    tool: String, arguments: [String],
    trimmingWhitespaceAndNewLines: Bool = true
) throws
    -> String
{
    @Dependency(\.urlForTool) var urlForTool
    @Dependency(\.runProcess) var runProcess

    let successPipe = Pipe()

    let process = Process()
    process.executableURL = try urlForTool(tool)
    process.arguments = arguments
    process.standardOutput = successPipe

    try runProcess(process, .stdoutOnly(.pipe(successPipe)))
    return try successPipe.contentsAsString()
}

extension Pipe {
    fileprivate func contentsAsString(trimmingWhitespaceAndNewLines: Bool = true) throws -> String {
        let data = fileHandleForReading.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .utf8) else {
            throw Error("Failed to convert pipe contents to string")
        }
        return trimmingWhitespaceAndNewLines
            ? string.trimmingCharacters(in: .whitespacesAndNewlines) : string
    }
}
