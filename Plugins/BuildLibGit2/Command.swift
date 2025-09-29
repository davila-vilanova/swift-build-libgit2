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
        guard let architectureArgument = arguments[safe: 2] else {
            throw PluginError("Which architecture to build for?")
        }

        let platforms = try platforms(from: platformArgument)
        let modalities = try buildModalities(from: architectureArgument, platforms: platforms)

        if libraries.contains(.openssl) {
            for platform in platforms {
                let architectures = try architectures(from: architectureArgument, for: platform)
                for architecture in architectures {
                    print("\nBuilding OpenSSL for \(platform) - \(architecture)...")
                    try buildOpenSSL(
                        context: context,
                        platform: platform,
                        architecture: architecture,
                        arguments: arguments
                    )
                }
            }
            // TODO: createOpenSSLXCFrameworks doesn't know anything about architectures yet
            try createOpenSSLXCFrameworks(with: context, platforms: platforms)
        }

        if libraries.contains(.libssh2) {
            for platform in platforms {
                let architectures = try architectures(from: architectureArgument, for: platform)
                print("\nBuilding libssh2 for \(platform), architectures: \(architectures)...")
                try buildLibSSH2(
                    context: context,
                    platform: platform,
                    architectures: architectures,
                    arguments: arguments
                )
            }

            try createLibSSH2Framework(with: context, platforms: platforms)
        }

        if libraries.contains(.libgit2) {
            for platform in platforms {
                let architectures = try architectures(from: architectureArgument, for: platform)
                print("\nBuilding libgit2 for \(platform), architectures: \(architectures)...")
                try buildLibGit2(
                    context: context,
                    platform: platform,
                    architectures: architectures,
                    arguments: arguments
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

// TODO: rename modalities to something else?
private func buildModalities(
    from architectureArgument: String,
    platforms: [Platform]
) throws -> [(Platform, Architecture)] {
    if architectureArgument == "all" {
        return Architecture.allCompatibleCombinations(with: platforms)
    }
    guard let architecture = Architecture(rawValue: architectureArgument) else {
        throw PluginError("\(architectureArgument) is not a valid architecture.")
    }
    return platforms.map { ($0, architecture) }
}

private func architectures(
    from architectureArgument: String,
    for platform: Platform
) throws -> [Architecture] {
    if architectureArgument == "all" {
        return Architecture.allCompatibleArchitectures(with: platform)
    } else {
        guard let architecture = Architecture(rawValue: architectureArgument) else {
            throw PluginError("\(architectureArgument) is not a valid architecture.")
        }
        return [architecture]
    }
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
