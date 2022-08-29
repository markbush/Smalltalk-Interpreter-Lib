protocol ObjectMemory {
  func hasObject(_ objectPointer: OOP) -> Bool
  // object pointer access
  func fetchPointer(_ fieldIndex: Int, ofObject objectPointer: OOP) -> OOP
  func storePointer(_ fieldIndex: Int, ofObject objectPointer: OOP, withValue valuePointer: OOP)
  // word access
  func fetchWord(_ wordIndex: Int, ofObject objectPointer: OOP) -> Word
  func storeWord(_ wordIndex: Int, ofObject objectPointer: OOP, withValue valueWord: Word)
  // byte access
  func fetchByte(_ byteIndex: Int, ofObject objectPointer: OOP) -> Byte
  func storeByte(_ byteIndex: Int, ofObject objectPointer: OOP, withValue valueByte: Byte)
  // reference counting
  func increaseReferencesTo(_ objectPointer: OOP)
  func decreaseReferencesTo(_ objectPointer: OOP)
  // class pointer access
  func fetchClassOf(_ objectPointer: OOP) -> OOP
  // length access
  func fetchWordLengthOf(_ objectPointer: OOP) -> Int
  func fetchByteLengthOf(_ objectPointer: OOP) -> Int
  // object creation
  func instantiateClass(_ classPointer: OOP, withPointers length: Int) -> OOP
  func instantiateClass(_ classPointer: OOP, withWords length: Int) -> OOP
  func instantiateClass(_ classPointer: OOP, withBytes length: Int) -> OOP
  // instance enumeration
  func initialInstanceOf(_ classPointer: OOP) -> OOP
  func instanceAfter(_ objectPointer: OOP) -> OOP
  // pointer swapping
  func swapPointersOf(_ firstPointer: OOP, and secondPointer: OOP)
  // integer access
  func integerValueOf(_ objectPointer: OOP) -> SignedWord
  func integerObjectOf(_ value: SignedWord) -> OOP
  func isIntegerObject(_ objectPointer: OOP) -> Bool
  func isIntegerValue(_ valueWord: SignedWord) -> Bool
  // direct loading of objects
  func loadImage(_ filename: String)
  func addObjectFromStandardImage(_ objectPointer: UInt16, inClass classOop: UInt16, withCount count: UInt8, isPointers: Bool, isOdd: Bool, body: [UInt16])
  // Extra
  func isStringValued(_ objectPointer: OOP) -> Bool
  func stringValueOf(_ objectPointer: OOP) -> String
}
