// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScarlettMidiControl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ScarlettMidiControl", targets: ["ScarlettMidiControl"])
    ],
    targets: [
        .target(
            name: "FocusriteControlKit",
            path: "Sources/FocusriteControlKit"
        ),
        .target(
            name: "PersistenceKit",
            path: "Sources/Persistence"
        ),
        .target(
            name: "MidiKit",
            dependencies: ["PersistenceKit"],
            path: "Sources/MidiKit"
        ),
        .executableTarget(
            name: "ScarlettMidiControl",
            dependencies: [
                "FocusriteControlKit",
                "MidiKit",
                "PersistenceKit"
            ],
            path: "App",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "FocusriteControlKitTests",
            dependencies: ["FocusriteControlKit"],
            path: "Tests/FocusriteControlKitTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ],
    swiftLanguageModes: [.v5]
)
