import Foundation
import Testing
@testable import IlacRaporKit

@Suite("PersonNameSuggester")
struct PersonNameSuggesterTests {
    @Test func normalizeTrims() {
        #expect(PersonNameSuggester.normalize("  Babam \n") == "Babam")
    }

    @Test func caseInsensitiveDedupKeepsLatestSpelling() {
        let u = [NameUsage(name: "babam", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Babam", usedAt: date(2026, 5, 1))]
        #expect(PersonNameSuggester.suggestions(for: "", from: u) == ["Babam"])
    }

    @Test func prefixMatchIgnoresCase() {
        let u = [NameUsage(name: "Babam", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Annem", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "bab", from: u) == ["Babam"])
    }

    @Test func turkishDottedAndDotlessI() {
        let u = [NameUsage(name: "İlknur", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Irmak", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "il", from: u) == ["İlknur"])
        #expect(PersonNameSuggester.suggestions(for: "ır", from: u) == ["Irmak"])
    }

    @Test func exactMatchIsNotSuggested() {
        let u = [NameUsage(name: "Babam", usedAt: date(2026, 1, 1))]
        #expect(PersonNameSuggester.suggestions(for: "babam", from: u).isEmpty)
    }

    @Test func latestFirstAndEmptyIgnored() {
        let u = [NameUsage(name: "Annem", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "  ", usedAt: date(2026, 3, 1)),
                 NameUsage(name: "Ablam", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "", from: u) == ["Ablam", "Annem"])
    }
}
