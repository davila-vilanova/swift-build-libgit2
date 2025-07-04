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
