import XCTest
@testable import EllevenLibs

final class EllevenLibsTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(EllevenLibs.version, "1.0.0")
    }
}
