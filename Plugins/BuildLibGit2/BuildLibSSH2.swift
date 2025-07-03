import Foundation
import PackagePlugin

func BuildLibSSH2(context: PluginContext, arguments: [String]) throws {
    print("iOS SDK Version: \(try getiOSSDKVersion(context: context))")
}
