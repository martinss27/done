import XCTest
@testable import Done

/// How a report's text becomes an issue title and body.
final class FeedbackTests: XCTestCase {

    func testFirstLineIsTheTitle() {
        let (title, body) = Feedback.split("  Alarm silent\nIt didn't ring.\n\n")
        XCTAssertEqual(title, "Alarm silent")
        XCTAssertEqual(body, "It didn't ring.")
    }

    func testLongFirstLineIsCutButNotLost() {
        let text = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces)
        let (title, body) = Feedback.split(text)
        XCTAssertEqual(title.count, 81, "80 characters plus the ellipsis")
        XCTAssertEqual(body, text)
    }
}
