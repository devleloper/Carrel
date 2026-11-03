/// The ruling and tone of a page. Paper is page content: it is stored with the page and exported with it.
public struct Paper: Hashable, Codable, Sendable {
    public var style: PaperStyle
    public var tone: PaperTone

    public init(style: PaperStyle, tone: PaperTone) {
        self.style = style
        self.tone = tone
    }

    public static let standard = Paper(style: .ruledWithMargin, tone: .cream)

    enum CodingKeys: String, CodingKey {
        case style
        case tone
    }
}

public enum PaperStyle: String, Codable, CaseIterable, Sendable {
    case blank
    case ruledNarrow
    case ruledWide
    case ruledWithMargin
    case grid
    case dots
}

/// The color of the paper. Every tone has been part of the stored format since version 1, so a notebook on any of
/// them opens in every build that reads that version.
public enum PaperTone: String, Codable, CaseIterable, Sendable {
    case white
    case cream
    case linen
    case night
}
