import XCTest
@testable import ShotScribeCore

final class SearchIndexTests: XCTestCase {

    private func shot(_ name: String, _ text: String, daysAgo: Int = 0) -> IndexedShot {
        IndexedShot(path: "/tmp/\(name).png", name: name,
                    captured: Date().addingTimeInterval(TimeInterval(-86_400 * daysAgo)),
                    indexed: Date(), size: 1, text: text)
    }

    private func store(_ shots: [IndexedShot]) -> ShotIndex.Store {
        var s = ShotIndex.Store()
        for x in shots { s.shots[x.path] = x }
        return s
    }

    /// The whole point of the index: finding a capture by something that was
    /// never in its name.
    func testFindsTextThatIsNotInTheFilename() {
        let s = store([shot("Real Belt Rail", "mounted onstage Export Rendered 10:41")])
        let hits = ShotIndex.search("onstage", in: s)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.shot.name, "Real Belt Rail")
        XCTAssertFalse(hits.first!.matchedInName)
    }

    /// A hit in the name outranks a hit in the body: the name is the one part
    /// somebody chose deliberately.
    func testNameMatchesOutrankBodyMatches() {
        let s = store([
            shot("Random console", "a passing mention of jumpcloud in the logs"),
            shot("JumpCloud drift", "unrelated body text"),
        ])
        let hits = ShotIndex.search("jumpcloud", in: s)
        XCTAssertEqual(hits.first?.shot.name, "JumpCloud drift")
        XCTAssertTrue(hits.first!.matchedInName)
    }

    func testAllTermsBeatSomeTerms() {
        let s = store([
            shot("one", "certificate expired on the gateway"),
            shot("two", "certificate renewed"),
        ])
        let hits = ShotIndex.search("certificate expired", in: s)
        XCTAssertEqual(hits.first?.shot.name, "one")
    }

    /// A result has to explain itself, or you must open the file to learn why
    /// it matched.
    func testSnippetShowsTheMatchInContext() {
        let long = String(repeating: "padding ", count: 40) + "NXDOMAIN resolving vpn.internal " + String(repeating: "tail ", count: 40)
        let s = store([shot("dns", long)])
        let hit = ShotIndex.search("NXDOMAIN", in: s).first
        XCTAssertNotNil(hit)
        XCTAssertTrue(hit!.snippet.contains("NXDOMAIN"))
        XCTAssertTrue(hit!.snippet.hasPrefix("…"), "a mid-text match should show it is excerpted")
        XCTAssertLessThan(hit!.snippet.count, 200)
    }

    func testEmptyQueryReturnsNothingRatherThanEverything() {
        let s = store([shot("a", "text"), shot("b", "text")])
        XCTAssertTrue(ShotIndex.search("", in: s).isEmpty)
        XCTAssertTrue(ShotIndex.search("   ", in: s).isEmpty)
    }

    func testEqualScoresBreakTowardTheMoreRecentShot() {
        let s = store([shot("older", "gateway", daysAgo: 30), shot("newer", "gateway", daysAgo: 1)])
        XCTAssertEqual(ShotIndex.search("gateway", in: s).first?.shot.name, "newer")
    }

    /// The round trip that silently broke search once: the encoder wrote
    /// ISO-8601 dates and the decoder expected the numeric default, so `load`
    /// returned an empty store while indexing reported success.
    func testStoreSurvivesARoundTripToDisk() throws {
        var s = ShotIndex.Store()
        let one = shot("round trip", "findable text")
        s.shots[one.path] = one

        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(s)
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(ShotIndex.Store.self, from: data)

        XCTAssertEqual(back.shots.count, 1)
        XCTAssertEqual(ShotIndex.search("findable", in: back).count, 1)
    }
}
