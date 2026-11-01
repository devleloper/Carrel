import NotebookDomain
import Testing

struct TitleTests {
    @Test func surroundingWhitespaceIsRemoved() {
        #expect(Title.normalized("  Linear Algebra \n") == "Linear Algebra")
    }

    @Test func blankTitlesAreRejected() {
        #expect(Title.normalized(" \n\t ") == nil)
    }
}
