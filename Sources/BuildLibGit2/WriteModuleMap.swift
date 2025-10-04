import Foundation

func writeModuleMap(inFrameworkAt frameworkURL: URL, platform: Platform, architecture: Architecture) throws {
    let innerDirectoryName = frameworkDirectoryName(for: platform, architecture: architecture)
    let destination = frameworkURL.appending(
        components: innerDirectoryName, "Headers", "module.modulemap")
    try moduleMap.write(to: destination, atomically: false, encoding: .utf8)
}

private func frameworkDirectoryName(for platform: Platform, architecture: Architecture) -> String {
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

private let moduleMap = """
module Clibgit2 {
	umbrella header "git2.h"

	export *
	module * { export * }

	// Exclude headers intended only for Microsoft compilers
	exclude header "git2/inttypes.h"
	exclude header "git2/stdint.h"

	// Explicit modules for headers not included in the umbrella header:
	explicit module cred_helpers {
		header "git2/cred_helpers.h"

		export *
	}

	explicit module trace {
		header "git2/trace.h"

		export *
	}

	// Explicit module for the "sys" headers:
	explicit module sys {
		umbrella "git2/sys"

		export *
		module * { export * }
	}

	link "curl"
	link "iconv"
	link "z"
}
"""
