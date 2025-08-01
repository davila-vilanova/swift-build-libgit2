enum Architecture: String {
    case arm64 = "arm64"
}

enum Platform: String, CaseIterable {
    case iPhoneOS
    case iPhoneSimulator
}

// TODO: Check what remains used at the end

func platformDirectoryName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "iPhoneOS.platform"
    case .iPhoneSimulator: "iPhoneSimulator.platform"
    }
}

func libraryDirectoryName(for platform: Platform) -> String {
    platform.rawValue
}

func systemName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "iOS"
    case .iPhoneSimulator: "iOS"  // TODO: Check
    }
}

func frameworkDirectoryName(for platform: Platform, architecture: Architecture) -> String {
    let platformSection =
        switch platform {
        case .iPhoneOS: "ios"
        case .iPhoneSimulator: "iOS"  // TODO: Check
        }

    let archSection =
        switch architecture {
        case .arm64: "arm64"
        }

    return "\(platformSection)-\(archSection)"
}

func sdkName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "iPhoneOS.sdk"
    case .iPhoneSimulator: "iPhoneSimulator.sdk"
    }
}

func destinationInFramework(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "generic/platform=iOS"
    case .iPhoneSimulator: "generic/platform=iOS Simulator"
    }
}
