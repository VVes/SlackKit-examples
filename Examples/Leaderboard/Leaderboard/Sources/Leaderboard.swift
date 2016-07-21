//
// Leaderboard.swift
//
// Copyright © 2016 Peter Zignego. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import SlackKit

class Leaderboard: MessageEventsDelegate {
    
    class Leaderboard {
        let teamID: String
        var scores: [String: Int] = [:]
        
        init(teamID: String) {
            self.teamID = teamID
        }
    }
    
    var leaderboards: [Leaderboard] = []
    let atSet = CharacterSet(charactersIn: "@")
    
    let bot: SlackKit
    
    init(clientID: String, clientSecret: String) {
        bot = SlackKit(clientID: clientID, clientSecret: clientSecret)
        bot.onClientInitalization = { (client: Client) in
            DispatchQueue.main.async(execute: {
                client.messageEventsDelegate = self
            })
        }
    }
    
    enum Command: String {
        case Leaderboard = "leaderboard"
    }
    
    enum Trigger: String {
        case PlusPlus = "++"
        case MinusMinus = "--"
    }
    
    // MARK: MessageEventsDelegate
    func messageReceived(_ client: Client, message: Message) {
        listen(client, message: message)
    }
    
    func messageSent(_ client: Client, message: Message){}
    func messageChanged(_ client: Client, message: Message){}
    func messageDeleted(_ client: Client, message: Message?){}
    
    // MARK: Leaderboard Internal Logic
    private func listen(_ client: Client, message: Message) {
        if let id = client.authenticatedUser?.id, let text = message.text {
            if text.lowercased().contains(Command.Leaderboard.rawValue) && text.contains(id) == true {
                handleCommand(client, command: .Leaderboard, channel: message.channel)
            }
        }
        if message.text?.contains(Trigger.PlusPlus.rawValue) == true {
            handleMessageWithTrigger(client, message: message, trigger: .PlusPlus)
        }
        if message.text?.contains(Trigger.MinusMinus.rawValue) == true {
            handleMessageWithTrigger(client, message: message, trigger: .MinusMinus)
        }
    }
    
    private func handleMessageWithTrigger(_ client: Client, message: Message, trigger: Trigger) {
        if let text = message.text, let lower = text.range(of: trigger.rawValue)?.lowerBound {
            let end = text.characters.index(before:lower)
            if let start = text.rangeOfCharacter(from: atSet, options: .backwards, range: text.startIndex..<end)?.lowerBound {
                if let id = client.team?.id, leaderboards.filter({$0.teamID == id}).count == 0 {
                    leaderboards.append(Leaderboard(teamID: id))
                }
                guard var leaderboard = leaderboards.filter({$0.teamID == client.team?.id}).first else {
                    return
                }
                let string = text.substring(from: start).substring(to: end)
                let users = client.users.values.filter{$0.id == self.userID(string)}
                if users.count > 0 {
                    let idString = userID(string)
                    initalizationForValue(&leaderboard, value: idString)
                    scoringForValue(&leaderboard, value: idString, trigger: trigger)
                } else {
                    initalizationForValue(&leaderboard, value: string)
                    scoringForValue(&leaderboard, value: string, trigger: trigger)
                }
            }
        }
    }
    
    private func handleCommand(_ client: Client, command: Command, channel:String?) {
        switch command {
        case .Leaderboard:
            if let id = channel {
                client.webAPI.sendMessage(id, text: "", linkNames: true, attachments: [constructLeaderboardAttachment(client)], success: {(response) in
                    
                    }, failure: { (error) in
                        print("Leaderboard failed to post due to error:\(error)")
                })
            }
        }
    }
    
    private func initalizationForValue(_ leaderboard: inout Leaderboard, value: String) {
        if leaderboard.scores[value] == nil {
            leaderboard.scores[value] = 0
        }
    }
    
    private func scoringForValue(_ leaderboard:inout Leaderboard, value: String, trigger: Trigger) {
        switch trigger {
        case .PlusPlus:
            leaderboard.scores[value]?+=1
        case .MinusMinus:
            leaderboard.scores[value]?-=1
        }
    }
    
    // MARK: Leaderboard Interface
    private func constructLeaderboardAttachment(_ client: Client) -> Attachment? {
        if let leaderboard = leaderboards.filter({$0.teamID == client.team?.id}).first {
            let 💯 = AttachmentField(title: "💯", value: swapIDsForNames(client, string: topItems(leaderboard)), short: true)
            let 💩 = AttachmentField(title: "💩", value: swapIDsForNames(client, string: bottomItems(leaderboard)), short: true)
            return Attachment(fallback: "Leaderboard", title: "Leaderboard", colorHex: AttachmentColor.Good.rawValue, text: "", fields: [💯, 💩])
        }
        return nil
    }
    
    private func topItems(_ leaderboard: Leaderboard) -> String {
        let sortedKeys = Array(leaderboard.scores.keys).sorted(isOrderedBefore: {leaderboard.scores[$0] > leaderboard.scores[$1]}).filter({leaderboard.scores[$0] > 0})
        let sortedValues = Array(leaderboard.scores.values).sorted(isOrderedBefore: {$0 > $1}).filter({$0 > 0})
        return leaderboardString(sortedKeys, values: sortedValues)
    }
    
    private func bottomItems(_ leaderboard: Leaderboard) -> String {
        let sortedKeys = Array(leaderboard.scores.keys).sorted(isOrderedBefore: {leaderboard.scores[$0] < leaderboard.scores[$1]}).filter({leaderboard.scores[$0] < 0})
        let sortedValues = Array(leaderboard.scores.values).sorted(isOrderedBefore: {$0 < $1}).filter({$0 < 0})
        return leaderboardString(sortedKeys, values: sortedValues)
    }
    
    private func leaderboardString(_ keys: [String], values: [Int]) -> String {
        var returnValue = ""
        for i in 0..<values.count {
            returnValue += keys[i] + " (" + "\(values[i])" + ")\n"
        }
        return returnValue
    }
    
    // MARK: - Utilities
    private func swapIDsForNames(_ client: Client, string: String) -> String {
        var returnString = string
        for key in client.users.keys {
            if let name = client.users[key]?.name {
                returnString = returnString.replacingOccurrences(of: key, with: "@"+name, options: NSString.CompareOptions.literal, range: returnString.startIndex..<returnString.endIndex)
            }
        }
        return returnString
    }
    
    private func userID(_ string: String) -> String {
        return string.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
    
}
