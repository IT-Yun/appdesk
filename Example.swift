import Foundation

@main
struct Example {
    static func main() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let request = AppDeskMessage(appID: .chagok, text: "Show the calendar changes", now: start, timeZone: .gmt)
        var thread = [request]
        var receipt = request
        receipt.state = "done"
        receipt.reply = "The calendar view now shows the saved item."
        receipt.updatedAt = start.timeIntervalSince1970 + 1
        try AppDeskMerge.apply([receipt], app: .chagok, to: &thread)
        try AppDeskMerge.apply([receipt], app: .chagok, to: &thread)
        precondition(thread.count == 1 && thread[0].reply == receipt.reply)
        print("One request, one reply, even after the receipt was delivered twice.")
    }
}
