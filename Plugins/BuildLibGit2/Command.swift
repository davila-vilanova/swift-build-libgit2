import Foundation
import PackagePlugin

// enum Library: String, CaseIterable, ExpressibleByArgument {
//     case openssl
//     case libssh2
//     case libgit2
//     case all
// }

@main
struct Command: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        print("\n")

        guard let firstArgument = arguments.first else {
            throw PluginError("Which library to build?")
        }

        switch firstArgument {
        case "openssl":
            try buildOpenSSL(context: context, arguments: arguments)
        case "libssh2":
            try buildLibSSH2(context: context, arguments: arguments)
        case "libgit2":
            try buildLibGit2(context: context, arguments: arguments)
        case "all":
            try buildOpenSSL(context: context, arguments: arguments)
            try buildLibSSH2(context: context, arguments: arguments)
            try buildLibGit2(context: context, arguments: arguments)
        default:
            throw PluginError("Unknown library: \(firstArgument).")
        }
    }
}
