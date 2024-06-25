// swift-tools-version:5.9
import PackageDescription

let package = Package(
 name: "Breakfast",
 platforms: [.macOS(.v13), .iOS(.v16)],
 products: [.library(name: "Breakfast", targets: ["Breakfast"])],
 dependencies: [
  .package(url: "https://github.com/acrlc/Core", branch: "main"),
  .package(url: "https://github.com/acrlc/Time", branch: "main"),
  .package(url: "https://github.com/acrlc/Benchmarks", branch: "main"),
  .package(url: "https://github.com/apple/swift-syntax", branch: "main")
 ],
 targets: [
  .target(
   name: "Breakfast", dependencies: [
    "Core",
     "Time",
    .product(
     name: "Extensions", package: "core"
    ),
    .product(
     name: "Components", package: "core"
    ),
    .product(
     name: "SwiftParser",
     package: "swift-syntax",
     condition: .when(platforms: [.macOS, .iOS, .windows, .linux])
    ),
    .product(
     name: "SwiftSyntax",
     package: "swift-syntax",
     condition: .when(platforms: [.macOS, .iOS, .windows, .linux])
    )
   ]
  ),
  .testTarget(
   name: "BreakfastTests", dependencies: ["Breakfast", "Benchmarks"]
  )
 ]
)
