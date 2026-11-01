import NotebookDomain
import SwiftUI

/// How each cover preset looks. Covers are objects on the desk, so they keep their colors in dark mode.
struct CoverAppearance {
    let name: LocalizedStringResource
    let base: Color
    let spine: Color
    let material: Material

    enum Material {
        case cloth
        case leather
        case linen
        case kraft
        case plain

        /// Leather catches more light than cloth or paper, so its sheen is stronger.
        var sheen: Double {
            switch self {
            case .leather: 0.16
            case .cloth, .linen: 0.08
            case .kraft, .plain: 0.05
            }
        }
    }

    init(_ preset: CoverPreset) {
        switch preset {
        case .forestCloth: self.init("Forest Cloth", base: 0x2F5D46, spine: 0x234836, .cloth)
        case .navyCloth: self.init("Navy Cloth", base: 0x26375A, spine: 0x1B2843, .cloth)
        case .burgundyCloth: self.init("Burgundy Cloth", base: 0x6E2433, spine: 0x521A26, .cloth)
        case .cognacLeather: self.init("Cognac Leather", base: 0x9A5B2E, spine: 0x7A4522, .leather)
        case .blackLeather: self.init("Black Leather", base: 0x2A2724, spine: 0x1B1917, .leather)
        case .oxbloodLeather: self.init("Oxblood Leather", base: 0x5C1F1C, spine: 0x431614, .leather)
        case .sandLinen: self.init("Sand Linen", base: 0xC9B48F, spine: 0xAE9A77, .linen)
        case .sageLinen: self.init("Sage Linen", base: 0x8FA38A, spine: 0x768B72, .linen)
        case .slateLinen: self.init("Slate Linen", base: 0x5F6B73, spine: 0x4B565D, .linen)
        case .naturalKraft: self.init("Natural Kraft", base: 0xB98D5D, spine: 0x9C7448, .kraft)
        case .charcoalKraft: self.init("Charcoal Kraft", base: 0x4A4540, spine: 0x38342F, .kraft)
        case .creamPlain: self.init("Cream", base: 0xEDE4D2, spine: 0xD9CDB6, .plain)
        }
    }

    private init(_ name: LocalizedStringResource, base: UInt32, spine: UInt32, _ material: Material) {
        self.name = name
        self.base = Color(uiColor: UIColor(hex: base))
        self.spine = Color(uiColor: UIColor(hex: spine))
        self.material = material
    }
}
