import Foundation
import PackagePlugin // TODO: remove once partial

enum Platform: String, CaseIterable {
    case iPhoneOS
    case iPhoneSimulator
    case macOS
}

enum Architecture: String, CaseIterable {
    case arm64
    case x86_64

    static func allCompatibleCombinations(with platforms: [Platform]) -> [(Platform, Architecture)] {
        platforms.flatMap { platform in
            Architecture.allCases.map { architecture in
                (platform, architecture)
            }
        }.filter(areCompatible)
    }

    // TODO: rename to allArchitecturesCompatible(with:)
    static func allCompatibleArchitectures(with platform: Platform) -> [Architecture] {
        Architecture.allCases.filter { areCompatible(platform: platform, architecture: $0) }
    }
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

private func cmakeArchitectureName(for architecture: Architecture) -> String {
    switch architecture {
    case .arm64: "arm64"
    case .x86_64: "x86_64"
    }
}

func cmakeArchitecturesValue(for architectures: [Architecture]) -> String {
    architectures.map(cmakeArchitectureName(for:)).joined(separator: ";")
}


func areCompatible(platform: Platform, architecture: Architecture) -> Bool {
    switch platform {
    case .iPhoneOS:
        return architecture == .arm64
    case .iPhoneSimulator, .macOS:
        return Set([Architecture.arm64, .x86_64]).contains(architecture)
    }
}


func allCompatiblePlatformsArchitectures() -> [(Platform, Architecture)] {
    Platform.allCases.flatMap { platform in
        Architecture.allCases.map { architecture in
            (platform, architecture)
        }
    }.filter(areCompatible)
}

struct IncompatiblePlatformArchitectureError: Error {
    let platform: Platform
    let architecture: Architecture
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
        case .x86_64: "x86_64"
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
