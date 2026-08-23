import XCTest
@testable import ShotScribeCore

final class LLMPreferenceTests: XCTestCase {

    private var backup: Data?

    override func setUpWithError() throws {
        backup = try? Data(contentsOf: LLMPreference.fileURL)
    }
    override func tearDownWithError() throws {
        if let backup {
            try FileManager.default.createDirectory(
                at: LLMPreference.fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try backup.write(to: LLMPreference.fileURL)
        } else {
            try? FileManager.default.removeItem(at: LLMPreference.fileURL)
        }
    }

    private func write(_ json: String) throws {
        try FileManager.default.createDirectory(
            at: LLMPreference.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data(json.utf8).write(to: LLMPreference.fileURL)
    }

    /// The gap this closes: the belt had a picker and nothing read it.
    func testItReadsWhatTheBeltWrites() throws {
        // The exact shape ToolbeltKit.LLMSettings encodes.
        try write(#"{"provider":"local","endpoint":"http://127.0.0.1:11434","model":"llama3"}"#)
        let pref = LLMPreference.load()
        XCTAssertEqual(pref.provider, .local)
        XCTAssertEqual(pref.endpoint, "http://127.0.0.1:11434")
        XCTAssertEqual(pref.model, "llama3")
        XCTAssertTrue(pref.isSet)
        XCTAssertTrue(pref.provider.usableHere)
    }

    func testNoFileMeansNobodyChoseRatherThanAChoice() throws {
        try? FileManager.default.removeItem(at: LLMPreference.fileURL)
        let pref = LLMPreference.load()
        XCTAssertFalse(pref.isSet, "absent must not read as a decision")
        XCTAssertNil(pref.mismatchNote, "nothing to warn about when nothing was chosen")
        XCTAssertTrue(pref.provider.usableHere, "and titling still works")
    }

    /// A corrupt file must not silently switch which model reads your screen.
    func testGarbageFallsBackRatherThanGuessing() throws {
        for junk in ["not json", "{}", #"{"provider":"nonesuch"}"#, ""] {
            try write(junk)
            let pref = LLMPreference.load()
            XCTAssertFalse(pref.isSet, "junk was treated as a setting: \(junk)")
            XCTAssertEqual(pref.provider, .claude)
        }
    }

    /// An unsupported choice degrades and says so, rather than failing.
    func testAnUnsupportedProviderIsAnnouncedNotIgnored() throws {
        try write(#"{"provider":"gemini"}"#)
        let pref = LLMPreference.load()
        XCTAssertTrue(pref.isSet)
        XCTAssertFalse(pref.provider.usableHere)
        let note = try XCTUnwrap(pref.mismatchNote)
        XCTAssertTrue(note.contains("Gemini"))
        XCTAssertTrue(note.contains("falls back"))
    }

    func testASupportedProviderSaysNothing() throws {
        try write(#"{"provider":"claude"}"#)
        XCTAssertNil(LLMPreference.load().mismatchNote)
    }
}
