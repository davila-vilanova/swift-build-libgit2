enum Architecture: String {
    case arm64 = "arm64"
}

enum Platform: String {
    case iPhoneOS = "iphoneos"
}

func systemName(for platform: Platform) -> String {
    switch platform {
    case .iPhoneOS:
        return "iOS"
    }
}

func frameworkDirectoryName(for platform: Platform, architecture: Architecture) -> String {
    let platformSection = switch platform {
        case .iPhoneOS: "ios"
    }

    let archSection = switch architecture {
        case .arm64: "arm64"
    }

    return "\(platformSection)-\(archSection)"
}
