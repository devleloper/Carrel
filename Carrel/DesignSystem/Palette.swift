import UIKit

/// Reading Room colors: the single source for UIKit views and, through `Theme`, for SwiftUI.
/// Every interface color has a light and a dark value.
enum Palette {
    static let desk = UIColor(light: 0xE9E1D3, dark: 0x1B1815)
    static let primaryText = UIColor(light: 0x2B241E, dark: 0xEEE6DA)
    static let secondaryText = UIColor(light: 0x65584B, dark: 0xABA092)
    static let accent = UIColor(light: 0x2F6B4F, dark: 0x84BD9D)
    static let secondaryAccent = UIColor(light: 0x9A6A2C, dark: 0xD8A866)
    static let destructive = UIColor(light: 0xB3261E, dark: 0xF28B82)
    static let pageShadow = UIColor(light: 0x3B2A1A, dark: 0x000000)
    /// Text printed on the paper labels of covers. Covers are objects on the desk and keep their colors in dark mode.
    static let coverLabelText = UIColor(hex: 0x2B241E)
    static let coverLabelPaper = UIColor(hex: 0xF6EEDC)
    /// Night paper looks the same in either theme, and so does its edge.
    static let nightPaperEdge = UIColor(white: 1, alpha: 0.08)
}
