import SwiftUI
import UIKit

/// Reading Room tokens. Every color has a light and a dark value; the UI never uses raw hex values directly.
enum Theme {
    static let desk = Color(light: 0xE9E1D3, dark: 0x1B1815)
    static let surface = Color(light: 0xF8F3EA, dark: 0x25211D)
    static let primaryText = Color(light: 0x2B241E, dark: 0xEEE6DA)
    static let secondaryText = Color(light: 0x65584B, dark: 0xABA092)
    static let accent = Color(light: 0x2F6B4F, dark: 0x84BD9D)
    static let secondaryAccent = Color(light: 0x9A6A2C, dark: 0xD8A866)
    static let separator = Color(light: 0xDDD2C2, dark: 0x3A332C)
    static let destructive = Color(light: 0xB3261E, dark: 0xF28B82)
    static let pageShadow = Color(light: 0x3B2A1A, dark: 0x000000)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Motion {
        static let chrome = Animation.spring(duration: 0.3, bounce: 0)
        static let morph = Animation.spring(duration: 0.4, bounce: 0.15)
        static let settle = Animation.spring(duration: 0.45, bounce: 0.1)
    }
}

extension Font {
    /// Titles use New York, the serif that carries the library-desk character of Reading Room.
    static func serifTitle(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif, weight: .semibold)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor(light: light, dark: dark))
    }
}

extension UIColor {
    nonisolated convenience init(light: UInt32, dark: UInt32) {
        self.init { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
