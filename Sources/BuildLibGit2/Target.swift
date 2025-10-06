import Dependencies
import Foundation

enum Platform: String, CaseIterable {
    case iPhoneOS
    case iPhoneSimulator
    case macOS
}

enum Architecture: String, CaseIterable {
    case arm64
    case x86_64
}

struct Target {
    let libraryName: String
    let platform: Platform
    let architectures: [Architecture]
    let binariesDirRelativePath: String  // to the install dir
    let headersDirRelativePath: String
    let outputBinaryNames: [String]

    init(
        libraryName: String,
        platform: Platform,
        architectures: [Architecture],
        binariesDirRelativePath: String,
        headersDirRelativePath: String,
        outputBinaryNames: [String]? = nil,
    ) {
        self.libraryName = libraryName
        self.platform = platform
        self.architectures = architectures
        self.binariesDirRelativePath = binariesDirRelativePath
        self.headersDirRelativePath = headersDirRelativePath
        self.outputBinaryNames = outputBinaryNames ?? [libraryName + ".a"]
    }

    var baseWorkDirectoryURL: URL {
        @Dependency(\.workDirectoryURL) var wd
        return wd.appending(component: libraryName)
    }

    var sourceDirURL: URL {
        baseWorkDirectoryURL.appending(component: "src")
    }

    // TODO: maybe rename
    var workDirectoryURL: URL {
        baseWorkDirectoryURL
            .appending(component: Self.filesystemFriendlyName(platform, architectures))
    }

    var buildDirURL: URL {
        workDirectoryURL.appending(component: "build")
    }

    var logURL: URL {
        workDirectoryURL.appending(component: "build.log")
    }

    var installDirURL: URL {
        workDirectoryURL.appending(component: "install")
    }

    var installBinaryURLs: [URL] {
        outputBinaryNames.map {
            installDirURL.appending(components: $0, binariesDirRelativePath, $0)
        }
    }

    func renamed(to newName: String) -> Target {
        return Target(
            libraryName: newName,
            platform: platform,
            architectures: architectures,
            binariesDirRelativePath: binariesDirRelativePath,
            headersDirRelativePath: headersDirRelativePath,
            outputBinaryNames: outputBinaryNames
        )
    }

    func splitIntoArchitectures() -> [Target] {
        architectures.compactMap {
            Target(
                libraryName: libraryName,
                platform: platform,
                architectures: [$0],
                binariesDirRelativePath: binariesDirRelativePath,
                headersDirRelativePath: headersDirRelativePath,
                outputBinaryNames: outputBinaryNames,
            )
        }.filter { Self.areCompatible($0.platform, $0.architectures.first!) }
    }

    /// Returns one target per platform
    static func targets(
        forLibraryNamed libraryName: String,
        platforms: [Platform],
        architectures: [Architecture],
        binariesLibRelativePath: String,
        headersDirRelativePath: String,
        outputBinaryNames: [String]? = nil
    ) -> [Target] {
        platforms.map { p in
            Target(
                libraryName: libraryName,
                platform: p,
                architectures: architectures.filter { a in areCompatible(p, a) },
                binariesDirRelativePath: binariesLibRelativePath,
                headersDirRelativePath: headersDirRelativePath,
                outputBinaryNames: outputBinaryNames
            )
        }
    }

    static func filesystemFriendlyName(
        _ platform: Platform,
        _ architectures: [Architecture]
    ) -> String {
        "\(platform.rawValue)-\(architectures.map { $0.rawValue }.joined(separator: "-"))"
    }

    private static func areCompatible(_ platform: Platform, _ architecture: Architecture) -> Bool {
        switch platform {
        case .iPhoneOS:
            return architecture == .arm64
        case .iPhoneSimulator, .macOS:
            return Set([Architecture.arm64, .x86_64]).contains(architecture)
        }
    }
}

struct IncompatiblePlatformArchitectureError: Swift.Error {
    let platform: Platform
    let architecture: Architecture
}

func sdkName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "iphoneos"
    case .iPhoneSimulator: "iphonesimulator"
    case .macOS: "macosx"
    }
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
