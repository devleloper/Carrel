import Foundation
import NotebookDomain
import Testing

struct PaperTests {
    @Test func toneChoicesFollowTheDesignOrder() {
        #expect(PaperTone.allCases == [.white, .cream, .linen, .night])
    }

    /// The raw values are what notebooks store; renaming a case would make those pages unreadable.
    @Test func everyToneKeepsItsStoredName() {
        #expect(PaperTone.allCases.map(\.rawValue) == ["white", "cream", "linen", "night"])
    }

    @Test func paperOnNewTonesRoundTrips() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let night = Paper(style: .dots, tone: .night)

        let data = try encoder.encode(night)

        #expect(String(decoding: data, as: UTF8.self) == #"{"style":"dots","tone":"night"}"#)
        #expect(try JSONDecoder().decode(Paper.self, from: data) == night)
        let linen = try JSONDecoder().decode(Paper.self, from: Data(#"{"style":"grid","tone":"linen"}"#.utf8))
        #expect(linen == Paper(style: .grid, tone: .linen))
    }
}
