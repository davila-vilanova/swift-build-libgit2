import Foundation
import PackagePlugin

@main
struct Command: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        print("\n")

        if arguments.contains("openssl") {
            try buildOpenSSL(context: context, arguments: arguments)
        } else if arguments.contains("libssh2") {
            try buildLibSSH2(context: context, arguments: arguments)
        } else {
            throw PluginError("Unknown command. Use 'openssl' or 'libssh2'.")
        }
    }
}
