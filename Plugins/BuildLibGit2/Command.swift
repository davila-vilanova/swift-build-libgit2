import Foundation
import PackagePlugin

// TODO: decide on closing parenthesis style
@main
struct Command: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        print("\n")

        guard let libraryArgument = arguments.first else {
            throw PluginError("Which library to build?")
        }
        let libraries = try libraries(from: libraryArgument)

        guard let platformArgument = arguments[safe: 1] else {
            throw PluginError("Which platform to build for?")
        }
        let platforms = try platforms(from: platformArgument)

        if libraries.contains(.openssl) {
            for platform in platforms {
                print("\nBuilding OpenSSL for \(platform)...")
                try buildOpenSSL(
                    context: context, platform: platform, arguments: arguments
                )
            }
            try createOpenSSLXCFrameworks(with: context, platforms: platforms)
        }

        if libraries.contains(.libssh2) {
            for platform in platforms {
                print("\nBuilding libssh2 for \(platform)...")
                try buildLibSSH2(
                    context: context, platform: platform, arguments: arguments
                )
            }
            try createLibSSH2Framework(with: context, platforms: platforms)
        }

        if libraries.contains(.libgit2) {
            for platform in platforms {
                print("\nBuilding libgit2 for \(platform)...")
                try buildLibGit2(
                    context: context, platform: platform, arguments: arguments
                )
            }
            try createLibGit2Framework(with: context, platforms: platforms)
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

private func libraries(from argument: String) throws -> Set<Library> {
    if argument == "all" {
        return Set(Library.allCases)
    }
    guard let library = Library(rawValue: argument) else {
        throw PluginError("\(argument) is not a valid library.")
    }
    return [library]
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

enum Library: String, CaseIterable, Equatable {
    case openssl
    case libssh2
    case libgit2
    case all
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

func fakeCMakeURL(_ context: PluginContext) -> URL? {
    useFakeTools ? context.package.directoryURL.appending(path: "fakecmake.sh") : nil
}
