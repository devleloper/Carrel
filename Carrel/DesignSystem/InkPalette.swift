import Foundation
import UIKit

/// Ink colors chosen to stay distinguishable on every paper tone and for common color-vision deficiencies.
/// Ink is content: these values are stored in drawings and look the same in light and dark mode.
enum InkPalette {
    struct Swatch: Identifiable {
        let name: LocalizedStringResource
        let hex: UInt32

        var id: UInt32 { hex }

        var color: UIColor {
            UIColor(hex: hex)
        }
    }

    static let carbon = Swatch(name: "Carbon", hex: 0x1E1E1C)
    static let inkBlue = Swatch(name: "Ink Blue", hex: 0x1649AE)
    static let sky = Swatch(name: "Sky", hex: 0x008CBA)
    static let green = Swatch(name: "Green", hex: 0x1F744F)
    static let moss = Swatch(name: "Moss", hex: 0x6E8B50)
    static let vermilion = Swatch(name: "Vermilion", hex: 0xCB380D)
    static let plum = Swatch(name: "Plum", hex: 0x912964)
    static let lavender = Swatch(name: "Lavender", hex: 0x84698B)
    static let sepia = Swatch(name: "Sepia", hex: 0x562B05)
    static let graphite = Swatch(name: "Graphite", hex: 0x7A7A7A)

    static let yellow = Swatch(name: "Yellow", hex: 0xFFE45C)
    static let blue = Swatch(name: "Blue", hex: 0x8CCBF2)
    static let pink = Swatch(name: "Pink", hex: 0xF4A6C8)
    static let mint = Swatch(name: "Mint", hex: 0x9FE2BF)

    static let pens = [carbon, inkBlue, sky, green, moss, vermilion, plum, lavender, sepia, graphite]
    static let highlighters = [yellow, blue, pink, mint]
}
