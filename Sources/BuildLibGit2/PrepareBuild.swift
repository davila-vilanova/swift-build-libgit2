import Foundation

// Sometimes you prepare a build for one architecture, (openssl)
// sometimes for several at time (libssh2, libgit2)
// This needs to set the install dir, for one or several architectures
// when the archs are several, that means all of the supported ones at once. Single install dir for that platform.
func prepareBuild(
    libraryName: String,
    // install dir is for sure going to depend on platform, and it's going to depend on architecture only if we're building for a single architecture.
    // however, we may be building for a single arch for more than one reason
    // reason 1 the library build system only supports one arch at a time
    // reason 2 the user wants to build only for this arch
    // get install dir might not depend on architecture at all. It is defined by the caller.
    // in the case of libssh2 and libgit2, architecture won't matter for the install dir. The binary put in there may be fat or thin.
    //    getInstallDir: (Platform, [Architecture]) -> URL,
    buildDirURL: URL,
    installDirURL: URL,
    // There should be a single platform per build
    //    platform: Platform,
    //    architectures: [Architecture],
    cloneRepository: () throws -> Void,
) throws -> FileHandle {
    try checkValidLibraryName(libraryName)

    let fileManager = FileManager.default

    // the result should always be be a single install dir,
    // because this is going to be a single build
    //    let installDir = getInstallDir(platform, architectures)
    let installDir = installDirURL

    // remember, this is going to be a single build
    //    let buildDir = context.workDirectoryURL
    //        .appending(component: "\(libraryName)_build_\(target.filesystemFriendlyName)")

    for dir in [installDir, buildDirURL] {
        if fileManager.fileExists(atPath: dir.path()) {
            try fileManager.removeItem(at: dir)
        }
        try fileManager.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    let logFile = buildDirURL.appending(
        component: "build.log"
    )
    fileManager.createFile(atPath: logFile.path(), contents: Data())
    print("Will log to \(logFile.path())")
    let logFileHandle = try FileHandle(forUpdating: logFile)

    try cloneRepository()

    //    let urls = BuildURLs(
    //        source: srcDir,
    //        build: buildDirURL,
    //        log: logFile,
    //        install: installDir
    //    )

    return logFileHandle
}

//struct BuildURLs {
//    let source: URL
//    let build: URL
//    let log: URL
//    let install: URL
//}

private func checkValidLibraryName(_ filename: String) throws {
    if filename.isEmpty {
        throw InvalidLibraryNameError(filename: filename)
    }
    // TODO: check suitable for part of filename
}

struct InvalidLibraryNameError: Swift.Error {
    let filename: String
}
