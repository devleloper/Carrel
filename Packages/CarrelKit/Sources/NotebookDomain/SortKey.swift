/// A position in an ordered list that can always be generated between two neighbours.
///
/// Ordering by fractional keys instead of array indices means inserting or moving an item changes only that item,
/// which keeps diffs small and lets two devices reorder independently once sync arrives.
public struct SortKey: RawRepresentable, Hashable, Comparable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func < (lhs: SortKey, rhs: SortKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The key for the first item of an empty list.
    public static let initial = SortKey.between(nil, nil)

    /// Returns a key strictly between `lower` and `upper`; `nil` means the start or the end of the list.
    public static func between(_ lower: SortKey?, _ upper: SortKey?) -> SortKey {
        // Equal or inverted neighbours can only come from damaged or externally edited data; appending after
        // `lower` keeps the list usable instead of failing.
        if let lower, let upper, lower >= upper {
            return between(lower, nil)
        }
        let lowerDigits = lower.map { digits(of: $0.rawValue) } ?? []
        let upperDigits = upper.map { digits(of: $0.rawValue) }
        var isBoundedAbove = upperDigits != nil
        var result: [Int] = []
        var position = 0

        while true {
            let low = position < lowerDigits.count ? lowerDigits[position] : 0
            let high: Int
            if isBoundedAbove, let upperDigits {
                // Keys this type generates never end in the lowest digit, so a valid `upper` always has a digit
                // here; a hand-made key like "a0" leaves no room below it, and the key goes after `lower`.
                guard position < upperDigits.count else {
                    return between(lower, nil)
                }
                high = upperDigits[position]
            } else {
                high = alphabet.count
            }

            if high - low > 1 {
                result.append((low + high) / 2)
                break
            }
            result.append(low)
            if high > low {
                isBoundedAbove = false
            }
            position += 1
        }
        return SortKey(rawValue: String(result.map { alphabet[$0] }))
    }

    private static let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    private static let digitValues = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) })

    private static func digits(of string: String) -> [Int] {
        string.map { digitValues[$0, default: 0] }
    }
}
