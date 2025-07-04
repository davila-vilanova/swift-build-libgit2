import Foundation
import PackagePlugin

func BuildLibSSH2(context: PluginContext, arguments: [String]) throws {
    let sdkInfo = try getSDKInfo(context: context, platform: .iPhoneOS)
    print("iOS SDK info: \(sdkInfo)")
}
