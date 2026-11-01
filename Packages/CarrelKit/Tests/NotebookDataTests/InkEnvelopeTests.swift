import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct InkEnvelopeTests {
    let ink = InkData(payload: Data((0..<512).map { UInt8($0 % 251) }), requiredContentVersion: 4)

    @Test func roundTripPreservesPayloadAndVersion() throws {
        #expect(try InkEnvelope.decode(InkEnvelope.encode(ink)) == ink)
    }

    enum Damage: CaseIterable {
        case truncated
        case bitFlip
        case empty
        case foreignMagic
    }

    @Test(arguments: Damage.allCases)
    func damagedFilesAreRejected(_ damage: Damage) {
        var data = InkEnvelope.encode(ink)
        switch damage {
        case .truncated:
            data.removeLast(10)
        case .bitFlip:
            data[data.count - 1] ^= 0x01
        case .empty:
            data = Data()
        case .foreignMagic:
            data.replaceSubrange(0..<4, with: Data("PDF%".utf8))
        }
        #expect(throws: InkEnvelopeError.self) {
            try InkEnvelope.decode(data)
        }
    }
}
