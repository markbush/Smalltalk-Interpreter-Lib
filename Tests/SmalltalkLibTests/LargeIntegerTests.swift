import XCTest
@testable import SmalltalkLib

final class LargeIntegerTests: XCTestCase {
  func testSimplePositiveAddition() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([2, 6, 3, 8], negative: false)
    let result = i1.add(i2)
    XCTAssertEqual(result.bytes, [6, 9, 5, 9])
    XCTAssertFalse(result.negative)
  }

  func testAddWithCarry() throws {
    let i1 = LargeInteger([235, 71], negative: false)
    let i2 = LargeInteger([53, 28], negative: false)
    let result = i1.add(i2)
    XCTAssertEqual(result.bytes, [32, 100])
    XCTAssertFalse(result.negative)
  }

  func testAddNegativeNumbers() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([2, 6, 3, 8], negative: true)
    let result = i1.add(i2)
    XCTAssertEqual(result.bytes, [6, 9, 5, 9])
    XCTAssertTrue(result.negative)
  }

  func testAddOppositeNumbers() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([2, 6, 3, 8], negative: false)
    let result = i1.add(i2)
    XCTAssertEqual(result.bytes, [254, 2, 1, 7])
    XCTAssertFalse(result.negative)
  }

  func testAddToZero() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.add(i2)
    XCTAssertEqual(result.bytes, [])
    XCTAssertFalse(result.negative)
  }
}
