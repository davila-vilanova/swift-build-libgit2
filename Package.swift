// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "build-libgit2-plugin",
    products: [
        .plugin(name: "BuildLibGit2", targets: ["BuildLibGit2"])
    ],
    targets: [
        .plugin(
            name: "BuildLibGit2",
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
            path: "Plugins/BuildLibGit2",
        )
    ]
)
