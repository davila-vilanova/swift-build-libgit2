import Foundation
import PackagePlugin

// TODO: decide on closing parenthesis style
@main
struct Command: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        print("I'm the plugin.")
    }
}
//
//struct Command: CommandPlugin {
//    func performCommand(context: Context, arguments: [String]) throws {
//        let modalities = try buildModalities(from: architectureArgument, platforms: platforms)
//
//
//
//    }
//}
//
//// TODO: rename modalities to something else?
//private func buildModalities(
//    from architectureArgument: String,
//    platforms: [Platform]
//) throws -> [(Platform, Architecture)] {
//    if architectureArgument == "all" {
//        return Architecture.allCompatibleCombinations(with: platforms)
//    }
//    guard let architecture = Architecture(rawValue: architectureArgument) else {
//        throw Error("\(architectureArgument) is not a valid architecture.")
//    }
//    return platforms.map { ($0, architecture) }
//}
//
//private func architectures(
//    from architectureArgument: String,
//    for platform: Platform
//) throws -> [Architecture] {
//    if architectureArgument == "all" {
//        return Architecture.allCompatibleArchitectures(with: platform)
//    } else {
//        guard let architecture = Architecture(rawValue: architectureArgument) else {
//            throw Error("\(architectureArgument) is not a valid architecture.")
//        }
//        return [architecture]
//    }
//}
//
//
//extension Array {
//    subscript(safe index: Int) -> Element? {
//        return indices.contains(index) ? self[index] : nil
//    }
//}
//
