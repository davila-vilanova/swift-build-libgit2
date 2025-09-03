import Foundation
import PackagePlugin

func getSystemCPUCount() -> Int {
    return ProcessInfo.processInfo.processorCount
}

func getXcodeDeveloperPath(context: PluginContext) throws -> String {
    try runToolForOutput(tool: "xcode-select", arguments: ["--print-path"], context: context)
}

struct SDKInfo {
    let version: String
    let url: URL
}

func getSDKInfo(context: PluginContext, platform: Platform) throws -> SDKInfo {
    let xcodebuildOutput = try runToolForOutput(
        tool: "xcodebuild",
        arguments: ["-version", "-sdk", platform.rawValue.lowercased()],
        // TODO: Use dedicated function to produce SDK name from platform, so that case names can change without breaking this.
        context: context
    )
    .split(separator: "\n")

    let versionLine =
        xcodebuildOutput.first(where: { $0.starts(with: "SDKVersion") })
    let pathLine =
        xcodebuildOutput.first(where: { $0.starts(with: "Path") })

    guard let version = versionLine?.split(separator: " ").last else {
        throw PluginError("Failed to find SDK version in xcodebuild output")
    }
    guard let path = pathLine?.split(separator: " ").last else {
        throw PluginError("Failed to find SDK path in xcodebuild output")
    }
    guard let url = URL(string: String(path)) else {
        throw PluginError("Invalid SDK path: \(path)")
    }
    return SDKInfo(version: String(version), url: url)
}

private func runToolForOutput(
    tool: String, arguments: [String], context: PluginContext,
    trimmingWhitespaceAndNewLines: Bool = true
) throws
    -> String
{
    let successPipe = Pipe()

    let process = Process()
    process.executableURL = try context.tool(named: tool).url
    process.arguments = arguments
    process.standardOutput = successPipe

    try runProcess(process, stdout: successPipe)
    return try successPipe.contentsAsString()
}

extension Pipe {
    fileprivate func contentsAsString(trimmingWhitespaceAndNewLines: Bool = true) throws -> String {
        let data = fileHandleForReading.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .utf8) else {
            throw PluginError("Failed to convert pipe contents to string")
        }
        return trimmingWhitespaceAndNewLines
            ? string.trimmingCharacters(in: .whitespacesAndNewlines) : string
    }
}
