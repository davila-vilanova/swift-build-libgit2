import Foundation
import ArgumentParser
import Dependencies

private let workDirectoryName = "build_libgit2_work"
private let outputDirectoryName = "build_libgit2_output"

@main
struct Build: ParsableCommand {
    @Option(name: [.short, .customLong("libs")]) var libraries: [Library] = Library.allCases
    @Option(name: [.short, .long]) var platforms: [Platform] = Platform.allCases
    @Option(name: [.short, .customLong("archs")]) var architectures: [Architecture] = Architecture
        .allCases

    mutating func run() throws {
        guard let workingDirectory = ProcessInfo.processInfo.environment["PWD"] else {
            throw Error("Cannot parse working directory from environment")
        }
        let workingDirectoryURL = URL(filePath: workingDirectory, directoryHint: .isDirectory)

        try withDependencies {
            $0.workDirectoryURL = workingDirectoryURL.appending(component: workDirectoryName)
            $0.outputDirectoryURL = workingDirectoryURL.appending(component: outputDirectoryName)
        } operation: {
            if libraries.contains(.openssl) {
                let targets = Target.targets(
                    forLibraryNamed: "openssl",
                    platforms: platforms,
                    architectures: architectures,
                    binariesLibRelativePath: "lib",
                    outputBinaryNames: ["libssl", "libcrypto"],
                )
                for t in targets {
                    try buildOpenSSL(target: t)
                }
                try createOpenSSLXCFrameworks(targets: targets)
            }
            //        if libraries.contains(.libssh2) {
            //            try buildLibSSH2(for: targets, with: context)
            //        }
            //        if libraries.contains(.libgit2) {
            //            try buildLibGit2(for: targets, with: context)
            //        }
        }
    }
}

//private func buildLibSSH2(for targets: [Target], with context: Context) throws {
//    for t in targets {
//        print("\nBuilding libssh2 for \(t.platform), architectures: \(t.architecture)...")
//        try BuildLibGit2.buildLibSSH2(
//            context: context,
//            platform: t.platform,
//            architectures: targets.architectures(for: t.platform),
//        )
//    }
//
//    try createLibSSH2Framework(with: context, platforms: targets.platforms)
//}
//
//private func buildLibGit2(for targets: [Target], with context: Context) throws {
//    for t in targets {
//        print("\nBuilding libgit2 for \(t.platform), architectures: \(t.architecture)...")
//        try BuildLibGit2.buildLibGit2(
//            context: context,
//            platform: t.platform,
//            architectures: targets.architectures(for: t.platform),
//        )
//    }
//    try createLibGit2Framework(with: context, platforms: targets.platforms)
//}

enum Library: String, CaseIterable, ExpressibleByArgument {
    case openssl
    case libssh2
    case libgit2
}

extension Platform: ExpressibleByArgument {}

extension Architecture: ExpressibleByArgument {}
