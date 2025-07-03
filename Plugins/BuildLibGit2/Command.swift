import Foundation
import PackagePlugin

@main
struct Command: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        if arguments.contains("openssl") {
            try BuildOpenSSL(context: context, arguments: arguments)
        } else if arguments.contains("libssh2") {
            try BuildLibSSH2(context: context, arguments: arguments)
        } else {
            throw PluginError("Unknown command. Use 'openssl' or 'libssh2'.")
        }
    }
}
