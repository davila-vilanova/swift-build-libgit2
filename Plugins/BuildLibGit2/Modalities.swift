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

func cmakeSystemName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS: "iOS"
    case .iPhoneSimulator: "iOS"
    }
}

func frameworkDirectoryName(for platform: Platform, architecture: Architecture) -> String {
    let platformSection =
        switch platform {
        case .iPhoneOS: "ios"
        case .iPhoneSimulator: "ios"
        }

    let archSection =
        switch architecture {
        case .arm64: "arm64"
        }

    let simulatorSection =
        switch platform {
        case .iPhoneOS: ""
        case .iPhoneSimulator: "simulator"
        }

    return [platformSection, archSection, simulatorSection]
        .filter { !$0.isEmpty }
        .joined(separator: "-")
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
