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

        guard let libraryArgument = arguments.first else {
            throw PluginError("Which library to build?")
        }

        guard let platformArgument = arguments[safe: 1] else {
            throw PluginError("Which platform to build for?")
        }
        let platforms = try platforms(from: platformArgument)

        switch libraryArgument {
        case "openssl":
            for platform in platforms {
                try buildOpenSSL(
                    context: context, platform: platform, arguments: arguments
                )
            }
            try createOpenSSLXCFrameworks(with: context, platforms: platforms)
        case "libssh2":
            try buildLibSSH2(context: context, arguments: arguments)
        case "libgit2":
            try buildLibGit2(context: context, arguments: arguments)
        case "all":
            break
//            try buildOpenSSL(context: context, arguments: arguments)
//            try buildLibSSH2(context: context, arguments: arguments)
//            try buildLibGit2(context: context, arguments: arguments)
        default:
            throw PluginError("Unknown library: \(libraryArgument).")
        }
    }
}

private func platforms(from argument: String) throws -> [Platform] {
    if argument == "all" {
        return Platform.allCases
    }
    guard let platform = Platform(rawValue: argument) else {
        throw PluginError("\(argument) is not a valid platform.")
    }
    return [platform]
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// For debugging
private let useFakeTools = false

func fakeXcodeBuildURL(_ context: PluginContext) -> URL? {
    useFakeTools ? context.package.directoryURL.appending(path: "fakexcodebuild.sh") : nil
}

func fakeConfigureURL(_ context: PluginContext) -> URL? {
    useFakeTools ? context.package.directoryURL.appending(path: "fakeconfigure.sh") : nil
}

func fakeMakeURL(_ context: PluginContext) -> URL? {
    useFakeTools ? context.package.directoryURL.appending(path: "fakemake.sh") : nil
}
