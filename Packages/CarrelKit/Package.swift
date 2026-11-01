// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CarrelKit",
    // macOS is listed only so the package tests run on the host with `swift test`; the app ships on iPad only.
    platforms: [.iOS("27.0"), .macOS("26.0")],
    products: [
        .library(name: "NotebookDomain", targets: ["NotebookDomain"]),
        .library(name: "NotebookData", targets: ["NotebookData"]),
    ],
    targets: [
        .target(name: "NotebookDomain"),
        .target(name: "NotebookData", dependencies: ["NotebookDomain"]),
        .testTarget(name: "NotebookDomainTests", dependencies: ["NotebookDomain"]),
        .testTarget(name: "NotebookDataTests", dependencies: ["NotebookData"]),
    ],
    swiftLanguageModes: [.v6]
)
