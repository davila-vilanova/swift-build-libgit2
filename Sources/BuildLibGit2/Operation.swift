import Foundation

enum Operation {
    case executeProcess(Process)
    case createDirectories([URL])
    case copyFileOrDirectory(origin: URL, destination: URL)
}
