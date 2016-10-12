import PackageDescription

let package = Package(
    name: "Leaderboard",
    targets: [],
    dependencies: [
        .Package(url: "https://github.com/pvzig/SlackKit.git", majorVersion: 3),
    ]
)
