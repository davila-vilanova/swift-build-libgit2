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
    let outputBinaryNames: [String]

    init(
        libraryName: String,
        platform: Platform,
        architectures: [Architecture],
        binariesDirRelativePath: String,
        outputBinaryNames: [String]? = nil,
    ) {
        self.libraryName = libraryName
        self.platform = platform
        self.architectures = architectures
        self.binariesDirRelativePath = binariesDirRelativePath
        self.outputBinaryNames = outputBinaryNames ?? [libraryName + ".a"]
    }

    func baseWorkDirectoryURL(_ context: Context) -> URL {
        context.workDirectoryURL.appending(component: libraryName)
    }

    func sourceDirURL(_ context: Context) -> URL {
        baseWorkDirectoryURL(context).appending(component: "src")
    }

    // TODO: maybe rename
    func workDirectoryURL(_ context: Context) -> URL {
        baseWorkDirectoryURL(context)
            .appending(component: Self.filesystemFriendlyName(platform, architectures))
    }

    func buildDirURL(_ context: Context) -> URL {
        workDirectoryURL(context).appending(component: "build")
    }

    func logURL(_ context: Context) -> URL {
        workDirectoryURL(context).appending(component: "build.log")
    }

    func installDirURL(_ context: Context) -> URL {
        workDirectoryURL(context).appending(component: "install")
    }

    func installBinaryURLs(_ context: Context) -> [URL] {
        outputBinaryNames.map {
            installDirURL(context)
                .appending(components: binariesDirRelativePath, $0)
        }
    }

    func renamed(to newName: String) -> Target {
        return Target(
            libraryName: newName,
            platform: platform,
            architectures: architectures,
            binariesDirRelativePath: binariesDirRelativePath,
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
        outputBinaryNames: [String]? = nil
    ) -> [Target] {
        platforms.map { p in
            Target(
                libraryName: libraryName,
                platform: p,
                architectures: architectures.filter { a in areCompatible(p, a) },
                binariesDirRelativePath: binariesLibRelativePath,
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
