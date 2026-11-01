import NotebookDomain
import SwiftUI

/// How each cover preset looks. Covers are objects on the desk, so they keep their colors in dark mode.
struct CoverAppearance {
    let name: String
    let base: Color
    let spine: Color
    let label: Color
    let material: Material

    enum Material {
        case cloth
        case leather
        case linen
        case kraft
        case plain
    }

    init(_ preset: CoverPreset) {
        switch preset {
        case .forestCloth: self.init("Forest Cloth", 0x2F5D46, 0x234836, .cloth)
        case .navyCloth: self.init("Navy Cloth", 0x26375A, 0x1B2843, .cloth)
        case .burgundyCloth: self.init("Burgundy Cloth", 0x6E2433, 0x521A26, .cloth)
        case .cognacLeather: self.init("Cognac Leather", 0x9A5B2E, 0x7A4522, .leather)
        case .blackLeather: self.init("Black Leather", 0x2A2724, 0x1B1917, .leather)
        case .oxbloodLeather: self.init("Oxblood Leather", 0x5C1F1C, 0x431614, .leather)
        case .sandLinen: self.init("Sand Linen", 0xC9B48F, 0xAE9A77, .linen)
        case .sageLinen: self.init("Sage Linen", 0x8FA38A, 0x768B72, .linen)
        case .slateLinen: self.init("Slate Linen", 0x5F6B73, 0x4B565D, .linen)
        case .naturalKraft: self.init("Natural Kraft", 0xB98D5D, 0x9C7448, .kraft)
        case .charcoalKraft: self.init("Charcoal Kraft", 0x4A4540, 0x38342F, .kraft)
        case .creamPlain: self.init("Cream", 0xEDE4D2, 0xD9CDB6, .plain)
        }
    }

    private init(_ name: String, _ base: UInt32, _ spine: UInt32, _ material: Material) {
        self.name = name
        self.base = Color(uiColor: UIColor(hex: base))
        self.spine = Color(uiColor: UIColor(hex: spine))
        self.label = Color(uiColor: UIColor(hex: 0xF6EEDC))
        self.material = material
    }
}
