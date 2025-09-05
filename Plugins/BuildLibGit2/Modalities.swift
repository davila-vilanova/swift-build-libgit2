import Foundation
import PackagePlugin // TODO: remove once partial

enum Architecture: String {
    case arm64 = "arm64"
}

enum Platform: String, CaseIterable {
    case iPhoneOS
    case iPhoneSimulator
    case macOS
}

func sdkName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "iphoneos"
    case .iPhoneSimulator: "iphonesimulator"
    case .macOS: "macosx"
    }
}

func libraryDirectoryName(for platform: Platform) -> String {
    platform.rawValue
}

func cmakeSystemName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "iOS"
    case .iPhoneSimulator: "iOS"
    case .macOS: "Darwin"
    }
}

func frameworkDirectoryName(for platform: Platform, architecture: Architecture) -> String {
    let platformSection =
        switch platform {
        case .iPhoneOS: "ios"
        case .iPhoneSimulator: "ios"
        case .macOS: "macos"
        }

    let archSection =
        switch architecture {
        case .arm64: "arm64"
        }

    let simulatorSection =
        switch platform {
        case .iPhoneOS: ""
        case .iPhoneSimulator: "simulator"
        case .macOS: ""
        }

    return [platformSection, archSection, simulatorSection]
        .filter { !$0.isEmpty }
        .joined(separator: "-")
}

func locationsForPlatforms(
    _ platforms: [Platform],
    libraryName: String,
    findLibraryDir: (PluginContext, Platform) -> URL,
    context: PluginContext
) -> ([URL], URL) {
    assert (!platforms.isEmpty)

    let binaries = platforms.map {
        findLibraryDir(context, $0).appending(components: "lib", "\(libraryName).a")
    }
    let headers = findLibraryDir(context, platforms.first!)
        .appending(component: "include")

    return (binaries, headers)
}
