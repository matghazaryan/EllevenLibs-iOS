import XCTest
@testable import EllevenLibs

final class EllevenLibsTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(EllevenLibs.version, "1.0.0")
    }

    func testLoggerInitialization() {
        let logger = ELogger(tag: "Test")
        XCTAssertNotNil(logger)
    }
}
