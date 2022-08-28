import XCTest
@testable import SmalltalkLib

final class ObjectMemoryTests: XCTestCase {
  private var memory: DictionaryObjectMemory!

  override func setUp() {
    super.setUp()
    memory = DictionaryObjectMemory()
  }
  override func tearDown() {
    memory = nil
    super.tearDown()
  }

  func testIntegerObject() throws {
    let integerObjectPointer: OOP = 1
    XCTAssertTrue(memory.isIntegerObject(integerObjectPointer), "object pointer \(integerObjectPointer) was not an integer object")
  }

  func testObjectIsNotIntegerObject() throws {
    let objectPointer: OOP = 2
    XCTAssertFalse(memory.isIntegerObject(objectPointer), "object pointer \(objectPointer) was an integer object")
  }

  func testInterObjectOfMinusOne() throws {
    let value: SignedWord = -1
    let objectPointer = memory.integerObjectOf(value)
    XCTAssertEqual(objectPointer, 0xffffffff, "object pointer of \(value) was \(objectPointer)")
  }

  func testInterValueOfMinusOne() throws {
    let objectPointer: OOP = 0xffffffff
    let value = memory.integerValueOf(objectPointer)
    XCTAssertEqual(value, -1, "integer value of \(objectPointer) was \(value)")
  }

  func testObjectValueOfZero() throws {
    let value: SignedWord = 0
    let objectPointer = memory.integerObjectOf(value)
    XCTAssertEqual(objectPointer, 1, "object pointer of \(value) was \(objectPointer)")
  }

  func testIntegerValueOfZero() throws {
    let objectPointer: OOP = 1
    let value = memory.integerValueOf(objectPointer)
    XCTAssertEqual(value, 0, "integer value of \(objectPointer) was \(value)")
  }

  func testObjectValueOfOne() throws {
    let value: SignedWord = 1
    let objectPointer = memory.integerObjectOf(value)
    XCTAssertEqual(objectPointer, 3, "object pointer of \(value) was \(objectPointer)")
  }

  func testIntegerValueOfOne() throws {
    let objectPointer: OOP = 3
    let value = memory.integerValueOf(objectPointer)
    XCTAssertEqual(value, 1, "integer value of \(objectPointer) was \(value)")
  }

  func testObjectValueOfTwo() throws {
    let value: SignedWord = 2
    let objectPointer = memory.integerObjectOf(value)
    XCTAssertEqual(objectPointer, 5, "object pointer of \(value) was \(objectPointer)")
  }

  func testIntegerValueOfTwo() throws {
    let objectPointer: OOP = 5
    let value = memory.integerValueOf(objectPointer)
    XCTAssertEqual(value, 2, "integer value of \(objectPointer) was \(value)")
  }

  func testNil() throws {
    memory.loadImage("files/Smalltalk-80.image")
    guard let nilEntry = memory.memory[OOPS.NilPointer] else {
      XCTFail("Missing nil")
      return
    }
    let nilObject = nilEntry.object
    XCTAssertEqual(nilEntry.count, 128, "nil should have count of 128 but was \(nilEntry.count)")
    XCTAssertEqual(nilObject.size(), 0, "nil should have size 0")
    let nilClassOop = nilObject.classOop // UndefinedObject
    guard let nilClassEntry = memory.memory[nilClassOop] else {
      XCTFail("Missing nil class (UndefinedObject)")
      return
    }
    let nilClass = nilClassEntry.object
    let nilClassBody = nilClass.body
    let nilClassNameOop = nilClassBody[6]
    guard let nilClassNameEntry = memory.memory[nilClassNameOop] else {
      XCTFail("Missing nil class name (oop: \(nilClassNameOop)")
      return
    }
    XCTAssertEqual(nilClassNameEntry.object.asString(), "UndefinedObject")
  }
}
