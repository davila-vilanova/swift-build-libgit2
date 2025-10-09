// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "build-libgit2",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .plugin(name: "BuildLibGit2Plugin", targets: ["BuildLibGit2Plugin"]),
        .executable(name: "BuildLibGit2", targets: ["BuildLibGit2"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0"),
    ],
    targets: [
        .plugin(
            name: "BuildLibGit2Plugin",
            capability: .command(
                intent: .custom(
                    verb: "build-libgit2",
                    description:
                        "Builds libgit2 and its dependencies and packages them as an .xcframework in the package directory."
                ),
                permissions: [
                    .allowNetworkConnections(
                        scope: .all(ports: [443]),
                        reason:
                            "This plugin uses the network to connect to a Git server and download libgit2 and its dependencies."
                    ),
                    .writeToPackageDirectory(
                        reason:
                            "This plugin writes the output .xcframeworks to the package directory"),
                ]),
            path: "Plugins/BuildLibGit2Plugin",
        ),
        .executableTarget(
            name: "BuildLibGit2",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]),
        .testTarget(
            name: "TestBuildLibGit2",
            dependencies: [
                "BuildLibGit2",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
    ]
)
