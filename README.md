# SlackKit Examples (Swift 2.2)
Example applications built with SlackKit.

For Swift 3 examples, look at the [`swift3` branch](https://github.com/pvzig/SlackKit-examples/tree/swift3).

## Leaderboard
A basic leaderboard scoring bot, in the spirit of [PlusPlus](https://plusplus.chat), built with [SlackKit](https://github.com/pvzig/SlackKit).

To configure it, enter your bot’s API token in `main.swift` for the Leaderboard bot:

```swift
let leaderboard = Leaderboard(clientID: "CLIENT-ID", clientSecret: "CLIENT-SECRET")
```

It adds a point for every `@thing++`, subtracts a point for every `@thing--`, and shows a leaderboard when asked `@botname leaderboard`.
