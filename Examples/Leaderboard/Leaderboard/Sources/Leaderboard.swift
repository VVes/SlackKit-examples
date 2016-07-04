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

import SlackKit
import Foundation

class Leaderboard: MessageEventsDelegate {
    
    var leaderboard: [String: Int] = [String: Int]()
    let atSet = NSCharacterSet(charactersInString: "@")

    let client: Client

    init(token: String) {
        client = Client(apiToken: token)
        client.messageEventsDelegate = self
    }

    enum Command: String {
        case Leaderboard = "leaderboard"
    }
    
    enum Trigger: String {
        case PlusPlus = "++"
        case MinusMinus = "--"
    }
    
    // MARK: MessageEventsDelegate
    func messageReceived(message: Message) {
        listen(message)
    }
    
    func messageSent(message: Message){}
    func messageChanged(message: Message){}
    func messageDeleted(message: Message?){}
    
    // MARK: Leaderboard Internal Logic
    private func listen(message: Message) {
        if let id = client.authenticatedUser?.id, text = message.text {
            if text.lowercaseString.containsString(Command.Leaderboard.rawValue) && text.containsString(id) == true {
                handleCommand(.Leaderboard, channel: message.channel)
            }
        }
        if message.text?.containsString(Trigger.PlusPlus.rawValue) == true {
            handleMessageWithTrigger(message, trigger: .PlusPlus)
        }
        if message.text?.containsString(Trigger.MinusMinus.rawValue) == true {
            handleMessageWithTrigger(message, trigger: .MinusMinus)
        }
    }
    
    private func handleMessageWithTrigger(message: Message, trigger: Trigger) {
        if let text = message.text,
            end = text.rangeOfString(trigger.rawValue)?.startIndex.predecessor(),
            start = text.rangeOfCharacterFromSet(atSet, options: .BackwardsSearch, range: text.startIndex..<end)?.startIndex {
            let string = text.substringWithRange(start...end)
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
    
    private func handleCommand(command: Command, channel:String?) {
        switch command {
        case .Leaderboard:
            if let id = channel {
                client.webAPI.sendMessage(id, text: "", linkNames: true, attachments: [constructLeaderboardAttachment()], success: {(response) in
                    
                    }, failure: { (error) in
                        print("Leaderboard failed to post due to error:\(error)")
                })
            }
        }
    }
    
    private func initalizationForValue(inout dictionary: [String: Int], value: String) {
        if dictionary[value] == nil {
            dictionary[value] = 0
        }
    }
    
    private func scoringForValue(inout dictionary: [String: Int], value: String, trigger: Trigger) {
        switch trigger {
        case .PlusPlus:
            dictionary[value]?+=1
        case .MinusMinus:
            dictionary[value]?-=1
        }
    }
    
    // MARK: Leaderboard Interface
    private func constructLeaderboardAttachment() -> Attachment? {
        let 💯 = AttachmentField(title: "💯", value: swapIDsForNames(topItems(&leaderboard)), short: true)
        let 💩 = AttachmentField(title: "💩", value: swapIDsForNames(bottomItems(&leaderboard)), short: true)
        return Attachment(fallback: "Leaderboard", title: "Leaderboard", colorHex: AttachmentColor.Good.rawValue, text: "", fields: [💯, 💩])
    }

    private func topItems(inout dictionary: [String: Int]) -> String {
        let sortedKeys = Array(dictionary.keys).sort({dictionary[$0] > dictionary[$1]}).filter({dictionary[$0] > 0})
        let sortedValues = Array(dictionary.values).sort({$0 > $1}).filter({$0 > 0})
        return leaderboardString(sortedKeys, values: sortedValues)
    }
    
    private func bottomItems(inout dictionary: [String: Int]) -> String {
        let sortedKeys = Array(dictionary.keys).sort({dictionary[$0] < dictionary[$1]}).filter({dictionary[$0] < 0})
        let sortedValues = Array(dictionary.values).sort({$0 < $1}).filter({$0 < 0})
        return leaderboardString(sortedKeys, values: sortedValues)
    }
    
    private func leaderboardString(keys: [String], values: [Int]) -> String {
        var returnValue = ""
        for i in 0..<values.count {
            returnValue += keys[i] + " (" + "\(values[i])" + ")\n"
        }
        return returnValue
    }
    
    // MARK: - Utilities
    private func swapIDsForNames(string: String) -> String {
        var returnString = string
        for key in client.users.keys {
            if let name = client.users[key]?.name {
                returnString = returnString.stringByReplacingOccurrencesOfString(key, withString: "@"+name, options: NSStringCompareOptions.LiteralSearch, range: returnString.startIndex..<returnString.endIndex)
            }
        }
        return returnString
    }
    
    private func userID(string: String) -> String {
        return string.stringByTrimmingCharactersInSet(NSCharacterSet.alphanumericCharacterSet().invertedSet)
    }
    
}