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

public enum PaperTone: String, Codable, CaseIterable, Sendable {
    case white
    case cream
    case linen
    case night

    /// Tones offered when creating a notebook; Linen and Night arrive with the 1.0 personalization work.
    public static let available: [PaperTone] = [.white, .cream]
}

/// Page dimensions in PostScript points, independent of the device that shows the page.
public struct PageSize: Hashable, Codable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let a4 = PageSize(width: 595.28, height: 841.89)
    public static let letter = PageSize(width: 612, height: 792)

    public var isLandscape: Bool {
        width > height
    }

    public var landscape: PageSize {
        PageSize(width: max(width, height), height: min(width, height))
    }

    public var portrait: PageSize {
        PageSize(width: min(width, height), height: max(width, height))
    }

    enum CodingKeys: String, CodingKey {
        case width
        case height
    }
}
