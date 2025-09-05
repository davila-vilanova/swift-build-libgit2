# swift-build-libgit2

## What this is

`swift-build-libgit2` is a Swift Package Manager plugin that builds `libgit2` (with its dependencies `openssl` and `libssh2`) for interoperability with Swift, supporting Apple platforms without having to remain limited to them.

## Work in progress

This is still a work in progress, but it already builds for iOS and the iOS Simulator.

## Installation and usage

### Add dependency

Add this plugin as a dependency to your `Package.swift`

```swift
    dependencies: [
        // ...
    		.package(url: "https://github.com/davila-vilanova/swift-build-libgit2"),
    ],
```

### Run build

From your package directory, execute:
```shell
$ swift package build-libgit2 all all
```
This will download the sources and build the libraries and XCFrameworks for `libssl`, `libcrypto`, `libssh2` and `libgit2`, for all supported platforms and architectures.

The currently downloaded and build versions of the libraries are:
- openssl (libssl and libcrypto): `openssl-3.5.1`
- libssh: `libssh2-1.11.1`
- libgit2: `v1.9.1`

### Add binary targets to your package manifest

Add the XCFrameworks that this plugin generated as binary targets in your `Package.swift`:

```swift
import PackageDescription

let package: Package = Package(
    // ...
    targets: [
        // ...
        .binaryTarget(
            name: "Clibgit2",
            path: "Frameworks/libgit2.xcframework"
        ),
        .binaryTarget(
            name: "libssh2",
            path: "Frameworks/libssh2.xcframework"
        ),
        .binaryTarget(
            name: "libcrypto",
            path: "Frameworks/libcrypto.xcframework"
        ),
        .binaryTarget(
            name: "libssl",
            path: "Frameworks/libssl.xcframework"
        ),
       // ...
    ]
)
```

Then add those binary targets as your target's dependencies:

```swift
import PackageDescription

let package: Package = Package(
    // ...
    targets: [
        .target(
            name: "MyTarget",
            dependencies: ["Clibgit2", "libssh2", "libcrypto", "libssl" /* ... */],
            path: "Sources/MyTarget"
        ),
       // ...
    ]
)
```

### Example Package.swift with all the additions

```swift
import PackageDescription

let package: Package = Package(
    // ...
    dependencies: [
        // ...
    		.package(url: "https://github.com/davila-vilanova/swift-build-libgit2"),
    ],
    targets: [
        .target(
            name: "MyTarget",
            dependencies: ["Clibgit2", "libssh2", "libcrypto", "libssl"],
            path: "Sources/MyTarget"
        ),
        .binaryTarget(
            name: "Clibgit2",
            path: "Frameworks/libgit2.xcframework"
        ),
        .binaryTarget(
            name: "libssh2",
            path: "Frameworks/libssh2.xcframework"
        ),
        .binaryTarget(
            name: "libcrypto",
            path: "Frameworks/libcrypto.xcframework"
        ),
        .binaryTarget(
            name: "libssl",
            path: "Frameworks/libssl.xcframework"
        ),
       // ...
    ]
)
```

### Importing libgit2 from your Swift source files

Use `import Clibgit2`. Note that `Clibgit2` is also the name of the corresponding binary target above, and it's the name exposed by the module map for each of the platforms in `libgit2.xcframework`.
