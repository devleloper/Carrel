import SwiftUI

/// Reading Room tokens. The colors wrap `Palette` for SwiftUI; the other tokens serve SwiftUI and UIKit alike.
enum Theme {
    static let desk = Color(uiColor: Palette.desk)
    static let primaryText = Color(uiColor: Palette.primaryText)
    static let secondaryText = Color(uiColor: Palette.secondaryText)
    static let accent = Color(uiColor: Palette.accent)
    static let secondaryAccent = Color(uiColor: Palette.secondaryAccent)
    static let destructive = Color(uiColor: Palette.destructive)
    static let pageShadow = Color(uiColor: Palette.pageShadow)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Opacity of the `pageShadow` under objects resting on the desk.
    enum Elevation {
        static let page = 0.12
        static let cover = 0.22
    }

    enum Motion {
        static let chrome = Animation.spring(duration: 0.3, bounce: 0)
        static let morph = Animation.spring(duration: 0.4, bounce: 0.15)
        static let settle = Animation.spring(duration: 0.45, bounce: 0.1)

        /// Under Reduce Motion every spring becomes the same short fade; views that move or scale drop that part
        /// of their transition too.
        static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeInOut(duration: 0.2) : animation
        }
    }
}

extension Font {
    /// New York, the serif that carries the library-desk character of Reading Room.
    static func serifTitle(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}
