import Foundation
import PackagePlugin

func getXcodeDeveloperPath(context: PluginContext) throws -> String {
    let successPipe = Pipe()

    let xcodeSelect = Process()
    xcodeSelect.executableURL = try context.tool(named: "xcode-select").url
    xcodeSelect.arguments = ["--print-path"]

    try runProcess(xcodeSelect, stdout: successPipe)
    let outputData = successPipe.fileHandleForReading.readDataToEndOfFile()
    guard let outputString = String(data: outputData, encoding: .utf8) else {
        throw PluginError("Failed to read output of xcode-select")
    }
    return
        outputString
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func getSystemCPUCount() -> Int {
    return ProcessInfo.processInfo.processorCount
}

func getiOSSDKVersion(context: PluginContext) throws -> String {
    let successPipe = Pipe()

    let xcodeBuild = Process()
    xcodeBuild.executableURL = try context.tool(named: "xcodebuild").url
    xcodeBuild.arguments = ["-version", "-sdk", "iphoneos"]

    try runProcess(xcodeBuild, stdout: successPipe)
    let outputData = successPipe.fileHandleForReading.readDataToEndOfFile()
    guard let outputString = String(data: outputData, encoding: .utf8) else {
        throw PluginError("Failed to read output of xcodebuild")
    }
    let versionLine =
        outputString
        .split(separator: "\n")
        .first(where: { $0.starts(with: "SDKVersion") })
    guard let version = versionLine?.split(separator: " ").last else {
        throw PluginError("Failed to find SDKVersion in xcodebuild output")
    }
    return String(version)
}
