// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Commander",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(
      name: "Commander",
      targets: ["Commander"]
    )
  ],
  targets: [
    .executableTarget(
      name: "Commander",
      path: ".",
      exclude: [
        "nix",
        "flake.nix",
        "flake.lock",
        "justfile",
        "README.md",
        "LICENSE",
        "docs",
        "Tests",
      ],
      sources: ["Sources/Commander"],
      resources: [
        .process("Assets")
      ]
    ),
    .testTarget(
      name: "CommanderTests",
      dependencies: ["Commander"],
      path: "Tests/CommanderTests"
    ),
  ]
)
