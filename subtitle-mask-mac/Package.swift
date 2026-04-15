// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "SubtitleMask",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "subtitle-mask", targets: ["SubtitleMask"])
  ],
  targets: [
    .executableTarget(
      name: "SubtitleMask",
      path: "Sources"
    )
  ]
)

