// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Profactor",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Profactor",
            targets: ["Profactor"]),
    ],
    dependencies: [
        // Apple
        .package(url: "https://github.com/apple/swift-algorithms.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", .upToNextMajor(from: "0.1.0")),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.0.0")),

        // Pointfree
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", .upToNextMajor(from: "0.1.4")),
        .package(url: "https://github.com/pointfreeco/swift-tagged.git", .upToNextMajor(from: "0.10.0")),
        .package(url: "https://github.com/pointfreeco/swift-nonempty.git", .upToNextMajor(from: "0.4.0")),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections.git", .upToNextMajor(from: "0.7.0")),

        // Other
        .package(url: "https://github.com/sideeffect-io/AsyncExtensions.git", .upToNextMajor(from: "0.5.2")),
        .package(url: "https://github.com/tgrapperon/swift-dependencies-additions.git", .upToNextMajor(from: "0.3.0")),
        .package(url: "https://github.com/Sajjon/BytePattern.git", .upToNextMajor(from: "0.0.3")),
        .package(url: "https://github.com/davdroman/swift-json-testing.git", .upToNextMajor(from: "0.1.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Profactor",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "AsyncExtensions", package: "AsyncExtensions"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesAdditions", package: "swift-dependencies-additions"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "NonEmpty", package: "swift-nonempty"),
                .product(name: "Tagged", package: "swift-tagged"),
            ]),
        .testTarget(
            name: "ProfactorTests",
            dependencies: [
                "Profactor",
                .product(name: "JSONTesting", package: "swift-json-testing"),
                .product(name: "XCTAssertBytesEqual", package: "BytePattern"),
                .product(name: "BytesMutation", package: "BytePattern"),
            ]),
    ]
)
