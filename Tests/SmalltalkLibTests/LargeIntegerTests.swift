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

  func testPositiveLessThanTrue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 4, 3, 2], negative: false)
    let result = i1.lessThan(i2)
    XCTAssertTrue(result)
  }

  func testPositiveLessThanFalse() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 4, 2], negative: false)
    let result = i1.lessThan(i2)
    XCTAssertFalse(result)
  }

  func testPositiveSameValueLessThan() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.lessThan(i2)
    XCTAssertFalse(result)
  }

  func testNegativeLessThanTrue() throws {
    let i1 = LargeInteger([5, 4, 3, 2], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThan(i2)
    XCTAssertTrue(result)
  }

  func testNegativeLessThanFalse() throws {
    let i1 = LargeInteger([5, 4, 2], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThan(i2)
    XCTAssertFalse(result)
  }

  func testNegativeSameValueLessThan() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThan(i2)
    XCTAssertFalse(result)
  }

  func testOppositeLessThanTrue() throws {
    let i1 = LargeInteger([5, 4, 3, 2], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.lessThan(i2)
    XCTAssertTrue(result)
  }

  func testOppositeLessThanFalse() throws {
    let i1 = LargeInteger([5, 4, 2], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThan(i2)
    XCTAssertFalse(result)
  }

  func testOppositeSameValueLessThan() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.lessThan(i2)
    XCTAssertTrue(result)
  }

  func testCloseNumbersLessThan() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 3, 2, 1], negative: false)
    let result = i1.lessThan(i2)
    XCTAssertTrue(result)
  }

  func testPositiveGreaterThanTrue() throws {
    let i1 = LargeInteger([5, 4, 3, 2], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThan(i2)
    XCTAssertTrue(result)
  }

  func testPositiveGreaterThanFalse() throws {
    let i1 = LargeInteger([5, 4, 2], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThan(i2)
    XCTAssertFalse(result)
  }

  func testPositiveSameValueGreaterThan() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThan(i2)
    XCTAssertFalse(result)
  }

  func testNegativeGreaterThanTrue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 4, 3, 2], negative: true)
    let result = i1.greaterThan(i2)
    XCTAssertTrue(result)
  }

  func testNegativeGreaterThanFalse() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 4, 2], negative: true)
    let result = i1.greaterThan(i2)
    XCTAssertFalse(result)
  }

  func testNegativeSameValueGreaterThan() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.greaterThan(i2)
    XCTAssertFalse(result)
  }

  func testOppositeGreaterThanTrue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 4, 3, 2], negative: true)
    let result = i1.greaterThan(i2)
    XCTAssertTrue(result)
  }

  func testOppositeGreaterThanFalse() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 4, 2], negative: false)
    let result = i1.greaterThan(i2)
    XCTAssertFalse(result)
  }

  func testOppositeSameValueGreaterThan() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.greaterThan(i2)
    XCTAssertTrue(result)
  }

  func testCloseNumbersGreaterThan() throws {
    let i1 = LargeInteger([5, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThan(i2)
    XCTAssertTrue(result)
  }

  func testEqualsWithSameValue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.equals(i2)
    XCTAssertTrue(result)
  }

  func testEqualsWithDifferentValues() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 3, 2, 1], negative: true)
    let result = i1.equals(i2)
    XCTAssertFalse(result)
  }

  func testPositiveLessThanOrEqualTrue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 4, 3, 2], negative: false)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testPositiveLessThanOrEqualFalse() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 4, 2], negative: false)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertFalse(result)
  }

  func testPositiveSameValueLessThanOrEqual() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testNegativeLessThanOrEqualTrue() throws {
    let i1 = LargeInteger([5, 4, 3, 2], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testNegativeLessThanOrEqualFalse() throws {
    let i1 = LargeInteger([5, 4, 2], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertFalse(result)
  }

  func testNegativeSameValueLessThanOrEqual() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testOppositeLessThanOrEqualTrue() throws {
    let i1 = LargeInteger([5, 4, 3, 2], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testOppositeLessThanOrEqualFalse() throws {
    let i1 = LargeInteger([5, 4, 2], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertFalse(result)
  }

  func testOppositeSameValueLessThanOrEqual() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testCloseNumbersLessThanOrEqual() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 3, 2, 1], negative: false)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testLessThanOrEqualWithSameValue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testLessThanOrEqualWithDifferentValues() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 3, 2, 1], negative: true)
    let result = i1.lessThanOrEqual(i2)
    XCTAssertFalse(result)
  }

  func testPositiveGreaterThanOrEqualTrue() throws {
    let i1 = LargeInteger([5, 4, 3, 2], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testPositiveGreaterThanOrEqualFalse() throws {
    let i1 = LargeInteger([5, 4, 2], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertFalse(result)
  }

  func testPositiveSameValueGreaterThanOrEqual() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testNegativeGreaterThanOrEqualTrue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 4, 3, 2], negative: true)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testNegativeGreaterThanOrEqualFalse() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 4, 2], negative: true)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertFalse(result)
  }

  func testNegativeSameValueGreaterThanOrEqual() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testOppositeGreaterThanOrEqualTrue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([5, 4, 3, 2], negative: true)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testOppositeGreaterThanOrEqualFalse() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 4, 2], negative: false)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertFalse(result)
  }

  func testOppositeSameValueGreaterThanOrEqual() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testCloseNumbersGreaterThanOrEqual() throws {
    let i1 = LargeInteger([5, 3, 2, 1], negative: false)
    let i2 = LargeInteger([4, 3, 2, 1], negative: false)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testGreaterThanOrEqualWithSameValue() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([4, 3, 2, 1], negative: true)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }

  func testGreaterThanOrEqualWithDifferentValues() throws {
    let i1 = LargeInteger([4, 3, 2, 1], negative: true)
    let i2 = LargeInteger([5, 3, 2, 1], negative: true)
    let result = i1.greaterThanOrEqual(i2)
    XCTAssertTrue(result)
  }
}
