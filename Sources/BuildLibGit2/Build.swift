import ArgumentParser
import Dependencies
import Foundation

private let workDirectoryName = "build_libgit2_work"
private let outputDirectoryName = "build_libgit2_output"

@main
struct Build: ParsableCommand {
    @Option(name: [.short, .customLong("libs")]) var libraries: [Library] = Library.allCases
    @Option(name: [.short, .long]) var platforms: [Platform] = Platform.allCases
    @Option(name: [.short, .customLong("archs")]) var architectures: [Architecture] = Architecture
        .allCases

    mutating func run() throws {
        let explicitWorkingDirectory = ProcessInfo.processInfo.environment["OPWD"]
        let implicitWorkingDirectory = ProcessInfo.processInfo.environment["PWD"]

        guard let workingDirectory = explicitWorkingDirectory ?? implicitWorkingDirectory else {
            throw Error("Cannot parse working directory from environment")
        }
        let workingDirectoryURL = URL(filePath: workingDirectory, directoryHint: .isDirectory)

        try withDependencies {
            $0.workDirectoryURL = workingDirectoryURL.appending(component: workDirectoryName)
            $0.outputDirectoryURL = workingDirectoryURL.appending(component: outputDirectoryName)
        } operation: {
            @Dependency(\.outputDirectoryURL) var outputDirectoryURL

            let openSSLTargets = Target.targets(
                forLibraryNamed: "openssl",
                platforms: platforms,
                architectures: architectures,
                binariesLibRelativePath: "lib",
                headersDirRelativePath: "include/openssl",
                outputBinaryNames: ["libssl", "libcrypto"],
            )
            let libSSH2Targets = Target.targets(
                forLibraryNamed: "libssh2",
                platforms: platforms,
                architectures: architectures,
                binariesLibRelativePath: "lib",
                headersDirRelativePath: "include",
            )
            let libGit2Targets = Target.targets(
                forLibraryNamed: "libgit2",
                platforms: platforms,
                architectures: architectures,
                binariesLibRelativePath: "lib",
                headersDirRelativePath: "include",
            )
            if libraries.contains(.openssl) {
                for t in openSSLTargets {
                    print("\nBuilding OpenSSL for \(t.platform), archs: \(t.architectures)")
                    try BuildOpenSSL.build(target: t)
                }
                try BuildOpenSSL.createXCFrameworks(for: openSSLTargets)
            }
            if libraries.contains(.libssh2) {
                for target in libSSH2Targets {
                    print(
                        "\nBuilding LibSSH2 for \(target.platform), archs: \(target.architectures)")
                    let openSSLTarget = openSSLTargets.first { $0.platform == target.platform }!
                    try buildLibSSH2(target: target, openSSLTarget: openSSLTarget)
                }
                try createLibSSH2Framework(targets: libSSH2Targets)
            }
            if libraries.contains(.libgit2) {
                for target in libGit2Targets {
                    print(
                        "\nBuilding LibGit2 for \(target.platform), archs: \(target.architectures)")
                    let openSSLTarget = openSSLTargets.first { $0.platform == target.platform }!
                    let libSSH2Target = libSSH2Targets.first { $0.platform == target.platform }!
                    try buildLibGit2(
                        target: target,
                        openSSLTarget: openSSLTarget,
                        libSSH2Target: libSSH2Target
                    )
                }
                try createLibGit2Framework(targets: libGit2Targets)
                try writeModuleMap(
                    inFrameworkAt: outputDirectoryURL.appending(
                        component: libGit2Targets.first!.libraryName
                    ).appendingPathExtension("xcframework"),
                    for: libGit2Targets
                )
            }
        }
    }
}

enum Library: String, CaseIterable, ExpressibleByArgument {
    case openssl
    case libssh2
    case libgit2
}

extension Platform: ExpressibleByArgument {}

extension Architecture: ExpressibleByArgument {}
