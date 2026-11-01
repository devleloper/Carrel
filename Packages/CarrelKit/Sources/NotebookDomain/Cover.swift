/// A notebook cover. A struct rather than the bare preset so custom covers can be added without a schema change.
public struct Cover: Hashable, Codable, Sendable {
    public var preset: CoverPreset

    public init(preset: CoverPreset) {
        self.preset = preset
    }

    enum CodingKeys: String, CodingKey {
        case preset
    }
}

public enum CoverPreset: String, Codable, CaseIterable, Sendable {
    case forestCloth
    case navyCloth
    case burgundyCloth
    case cognacLeather
    case blackLeather
    case oxbloodLeather
    case sandLinen
    case sageLinen
    case slateLinen
    case naturalKraft
    case charcoalKraft
    case creamPlain
}
