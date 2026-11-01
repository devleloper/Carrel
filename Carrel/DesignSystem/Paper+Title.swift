import NotebookDomain
import SwiftUI

extension PaperStyle {
    var title: LocalizedStringKey {
        switch self {
        case .blank: "Blank"
        case .ruledNarrow: "Narrow Ruled"
        case .ruledWide: "Wide Ruled"
        case .ruledWithMargin: "Ruled with Margin"
        case .grid: "Grid"
        case .dots: "Dots"
        }
    }
}

extension PaperTone {
    var title: LocalizedStringKey {
        switch self {
        case .white: "White"
        case .cream: "Cream"
        case .linen: "Linen"
        case .night: "Night"
        }
    }
}
