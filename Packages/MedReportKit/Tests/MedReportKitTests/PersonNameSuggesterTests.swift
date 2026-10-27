import Foundation
import Testing
@testable import MedReportKit

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

    @Test func turkishCaseRulesStillMatch() {
        let u = [NameUsage(name: "İlknur", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Irmak", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "il", from: u) == ["İlknur"])
        #expect(PersonNameSuggester.suggestions(for: "ır", from: u) == ["Irmak"])
    }

    @Test func exactMatchIsNotSuggested() {
        let u = [NameUsage(name: "Babam", usedAt: date(2026, 1, 1))]
        #expect(PersonNameSuggester.suggestions(for: "Babam", from: u).isEmpty)
        #expect(PersonNameSuggester.suggestions(for: "babam", from: u) == ["Babam"])  // offers the saved spelling
    }

    @Test func latestFirstAndEmptyIgnored() {
        let u = [NameUsage(name: "Annem", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "  ", usedAt: date(2026, 3, 1)),
                 NameUsage(name: "Ablam", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "", from: u) == ["Ablam", "Annem"])
    }

    @Test func dotlessAndDottedIAreTheSameLetter() {
        let u = [NameUsage(name: "Irene", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Irmak", usedAt: date(2026, 2, 1)),
                 NameUsage(name: "İlknur", usedAt: date(2026, 3, 1))]
        #expect(PersonNameSuggester.suggestions(for: "ir", from: u) == ["Irmak", "Irene"])
        #expect(PersonNameSuggester.suggestions(for: "ır", from: u) == ["Irmak", "Irene"])
        #expect(PersonNameSuggester.suggestions(for: "İl", from: u) == ["İlknur"])
    }

    @Test func diacriticsAreIgnored() {
        let u = [NameUsage(name: "Şükrü", usedAt: date(2026, 1, 1))]
        #expect(PersonNameSuggester.suggestions(for: "sukru", from: u) == ["Şükrü"])  // full loose match
        #expect(PersonNameSuggester.suggestions(for: "Şükrü", from: u).isEmpty)        // exact spelling
        #expect(PersonNameSuggester.suggestions(for: "suk", from: u) == ["Şükrü"])
    }

    @Test func looseDuplicatesMerge() {
        let u = [NameUsage(name: "Sule", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Şule", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "", from: u) == ["Şule"])
    }
}
