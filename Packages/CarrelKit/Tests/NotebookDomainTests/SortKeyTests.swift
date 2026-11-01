import NotebookDomain
import Testing

struct SortKeyTests {
    @Test func keyBetweenNeighboursIsStrictlyBetween() {
        let pairs: [(String?, String?)] = [(nil, nil), ("a", "b"), ("a", "a5"), ("a1", "a2"), (nil, "1"), ("zz", nil)]
        for (lower, upper) in pairs {
            let key = SortKey.between(lower.map(SortKey.init), upper.map(SortKey.init))
            if let lower {
                #expect(key > SortKey(rawValue: lower))
            }
            if let upper {
                #expect(key < SortKey(rawValue: upper))
            }
        }
    }

    @Test func repeatedInsertionAtTheFrontStaysOrdered() {
        var keys = [SortKey.initial]
        for _ in 0..<200 {
            keys.insert(.between(nil, keys[0]), at: 0)
        }
        #expect(keys == keys.sorted())
        #expect(Set(keys).count == keys.count)
    }

    @Test func repeatedInsertionInTheMiddleStaysOrdered() {
        var keys = SortKey.sequence(count: 2)
        for _ in 0..<200 {
            keys.insert(.between(keys[0], keys[1]), at: 1)
        }
        #expect(keys == keys.sorted())
        #expect(Set(keys).count == keys.count)
    }

    @Test func invertedNeighboursStillProduceAKeyAfterTheLowerOne() {
        let key = SortKey.between(SortKey(rawValue: "m"), SortKey(rawValue: "c"))
        #expect(key > SortKey(rawValue: "m"))
    }
}
