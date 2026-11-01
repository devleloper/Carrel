import UIKit

/// Ink colors chosen to stay distinguishable on every paper tone and for common color-vision deficiencies.
/// Ink is content: these values are stored in drawings and look the same in light and dark mode.
enum InkPalette {
    struct Swatch: Identifiable, Hashable {
        let name: String
        let hex: UInt32

        var id: UInt32 { hex }

        var color: UIColor {
            UIColor(hex: hex)
        }
    }

    static let pens: [Swatch] = [
        Swatch(name: "Carbon", hex: 0x1E1E1C),
        Swatch(name: "Ink Blue", hex: 0x1649AE),
        Swatch(name: "Sky", hex: 0x008CBA),
        Swatch(name: "Green", hex: 0x1F744F),
        Swatch(name: "Moss", hex: 0x6E8B50),
        Swatch(name: "Vermilion", hex: 0xCB380D),
        Swatch(name: "Plum", hex: 0x912964),
        Swatch(name: "Lavender", hex: 0x84698B),
        Swatch(name: "Sepia", hex: 0x562B05),
        Swatch(name: "Graphite", hex: 0x7A7A7A),
    ]

    static let highlighters: [Swatch] = [
        Swatch(name: "Yellow", hex: 0xFFE45C),
        Swatch(name: "Blue", hex: 0x8CCBF2),
        Swatch(name: "Pink", hex: 0xF4A6C8),
        Swatch(name: "Mint", hex: 0x9FE2BF),
    ]
}
