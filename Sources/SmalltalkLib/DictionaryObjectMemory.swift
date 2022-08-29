import Foundation

// The default size of an object pointer.
// UInt32 allows for 2,147,483,647 objects and
// SmallInteger values from -2,147,483,648 to 2,147,483,647
// which should be plenty for most people!
typealias Byte = UInt8
typealias Word = UInt32
typealias SignedWord = Int32
// An object pointer is a Word
typealias OOP = Word

class DictionaryObjectMemory : ObjectMemory {
  static var nextOop: OOP = 65534
  static let RootObjects = stride(from: OOPS.NilPointer, through: OOPS.ClassSymbolPointer, by: 2)
  let ClassNameIndex = 6
  let BytesPerWord = MemoryLayout<Word>.size
  var ByteMasks: [Word] = []
  var ByteShifts: [Int] = []
  let MinInt = SignedWord.min / 2
  let MaxInt = SignedWord.max / 2
  var memory: [OOP:ObjectTableEntry] = [:]

  static func nextAvailableOop() -> OOP {
    let oop = nextOop
    nextOop += 2
    return oop
  }

  init() {
    ByteMasks = [Word](repeating: 0, count: BytesPerWord)
    ByteShifts = [Int](repeating: 0, count: BytesPerWord)
    for i in 0 ..< ByteMasks.count {
      ByteMasks[i] = Word(0xFF << ((ByteMasks.count - i - 1) * 8))
      ByteShifts[i] = (ByteMasks.count - i - 1) * 8
    }
  }

  func loadImage(_ filename: String) {
    let url = URL(fileURLWithPath: filename)
    do {
      let data = try Data(contentsOf: url)
      // Bytes 8 and 9 are 0 if this is a standard Smalltalk-80 image
      let standardImage = (data[8] == 0) && (data[9] == 0)
      if (standardImage) {
        let imageReader = Smalltalk80ImageFileReader(data)
        imageReader.loadInto(self)
      }
      DictionaryObjectMemory.nextOop = OOP(memory.keys.max() ?? 65534) + 2
    } catch {
      fatalError("Cannot read from \(filename)")
    }
  }
  func loadDefaultImage() {
    loadImage("files/Smalltalk-80.image")
  }
  func nameForClass(_ classPointer: OOP) -> String {
    let namePointer = fetchPointer(ClassNameIndex, ofObject: classPointer)
    if isStringValued(namePointer) {
      return stringValueOf(namePointer)
    } else {
      return "<unknown>"
    }
  }
  func classNameFor(_ objectPointer: OOP) -> String {
    let classPointer = fetchClassOf(objectPointer)
    return nameForClass(classPointer)
  }
  func isStringValued(_ objectPointer: OOP) -> Bool {
    let theClass = fetchClassOf(objectPointer)
    return (theClass == OOPS.ClassSymbolPointer) || (theClass == OOPS.ClassStringPointer) || (theClass == OOPS.ClassCharacterPointer)
  }
  func stringValueOf(_ objectPointer: OOP) -> String {
    if isIntegerObject(objectPointer) {
      return "\(integerValueOf(objectPointer))"
    }
    if fetchClassOf(objectPointer) == OOPS.ClassFloatPointer {
      return memory[objectPointer]?.object.asString() ?? "0.0"
    }
    if fetchClassOf(fetchClassOf(objectPointer)) == 60 {
      return nameForClass(objectPointer)
    }
    switch objectPointer {
    case OOPS.NilPointer: return "nil"
    case OOPS.FalsePointer: return "false"
    case OOPS.TruePointer: return "true"
    case OOPS.SmalltalkPointer: return "Smalltalk"
    default:
      if isStringValued(objectPointer) {
        return memory[objectPointer]?.object.asString() ?? ""
      }
      let className = classNameFor(objectPointer)
      if let first = className.first {
        let vowel = ["a", "e", "i", "o", "u"].contains(first.lowercased())
        let prefix = vowel ? "an" : "a"
        return "\(prefix) \(className)"
      }
      return "<unknown>"
    }
  }
  func addObjectFromStandardImage(_ objectPointer: UInt16, inClass classOop: UInt16, withCount count: UInt8, isPointers: Bool, isOdd: Bool, body: [UInt16]) {
    // Standard image includes size and class in size
    let object = objectFromStandardImage(objectPointer, inClass: classOop, isPointers: isPointers, isOdd: isOdd, body: body)
    let tableEntry = ObjectTableEntry(forObject: object)
    tableEntry.count = Word(count)
    memory[OOP(objectPointer)] = tableEntry
  }
  func objectFromStandardImage(_ objectPointer: UInt16, inClass classOop: UInt16, isPointers: Bool, isOdd: Bool, body: [UInt16]) -> STObject {
    if classOop == OOPS.ClassFloatPointer {
      return floatFromStandardImage(objectPointer, body: body)
    }
    if classOop == OOPS.ClassCompiledMethod {
      return compiledMethodFromStandardImage(objectPointer, isOdd: isOdd, body: body)
    }
    if isPointers {
      return pointerObjectFromStandardImage(objectPointer, inClass: classOop, body: body)
    }
    return byteObjectFromStandardImage(objectPointer, isOdd: isOdd, inClass: classOop, body: body)
  }
  func pointerObjectFromStandardImage(_ objectPointer: UInt16, inClass classOop: UInt16, body: [UInt16]) -> STObject {
    // New object will be the same size
    let newBody = body.map { objectPointer in OOP(objectPointer) }
    let object = STObject(size: body.count, oddBytes: 0, isPointers: true, inClass: OOP(classOop))
    object.body = newBody
    return object
  }
  func byteObjectFromStandardImage(_ objectPointer: UInt16, isOdd: Bool, inClass classOop: UInt16, body: [UInt16]) -> STObject {
    // body contains bytes
    let origSize = body.count
    let byteSize = isOdd ? ((origSize*2) - 1) : (origSize*2)
    // New object will be smaller with bytes more packed
    let wordSize = (byteSize + BytesPerWord - 1) / BytesPerWord
    let oddBytes = (byteSize % BytesPerWord) == 0 ? 0 : (BytesPerWord - (byteSize % BytesPerWord))
    let object = STObject(size: wordSize, oddBytes: oddBytes, isPointers: false, inClass: OOP(classOop))
    for byteNum in 0 ..< byteSize {
      let sourceWordNum: Int = byteNum / 2
      let sourceWord = body[sourceWordNum]
      let sourceOffset = byteNum % 2
      let byteOfWord = (sourceOffset == 1) ? (sourceWord >> 8) : sourceWord
      let byte = Word(byteOfWord & 0xFF)

      let destWordNum = byteNum / BytesPerWord
      let destByteNum = byteNum % BytesPerWord
      let destOldWord = object.body[destWordNum]
      let shift = (BytesPerWord - destByteNum - 1) * 8
      let destNewValue = byte << shift
      object.body[destWordNum] = (destOldWord & ~ByteMasks[destByteNum]) | destNewValue
    }
    return object
  }
  func compiledMethodFromStandardImage(_ objectPointer: UInt16, isOdd: Bool, body: [UInt16]) -> STObject {
    // Must have a method header
    let methodHeader = body[0]
    let numPointers = Int(1 + ((methodHeader & 126) >> 1)) // including the header
    // body must have at least a header, the literals, and 0 or more bytecodes
    if body.count < numPointers {
      // TODO fix up to raise error to user
      fatalError("Invalid CompiledMethod for OOP: \(objectPointer)")
    }
    let byteWords = body.count - numPointers
    let byteSize = isOdd ? ((byteWords*2)-1) : (byteWords*2)
    if byteSize < 0 {
      // TODO fix up to raise error to user
      fatalError("Invalid CompiledMethod for OOP: \(objectPointer) (negative number of bytecodes!)")
    }
    let wordSize = (byteSize + BytesPerWord - 1) / BytesPerWord
    let oddBytes = (byteSize % BytesPerWord) == 0 ? 0 : (BytesPerWord - (byteSize % BytesPerWord))
    let actualSize = numPointers + wordSize
    let object = STObject(size: actualSize, oddBytes: oddBytes, isPointers: false, inClass: OOPS.ClassCompiledMethod)
    for wordNum in 0 ..< numPointers {
      object.body[wordNum] = OOP(body[wordNum])
    }
    for byteNum in 0 ..< byteSize {
      let sourceWordNum: Int = numPointers + (byteNum / 2)
      let sourceWord = body[sourceWordNum]
      let sourceOffset = byteNum % 2
      let byteOfWord = (sourceOffset == 1) ? (sourceWord >> 8) : sourceWord
      let byte = Word(byteOfWord & 0xFF)

      let destWordNum = numPointers + (byteNum / BytesPerWord)
      let destByteNum = byteNum % BytesPerWord
      let destOldWord = object.body[destWordNum]
      let shift = (BytesPerWord - destByteNum - 1) * 8
      let destNewValue = byte << shift
      object.body[destWordNum] = (destOldWord & ~ByteMasks[destByteNum]) | destNewValue
    }
    return object
  }
  func floatFromStandardImage(_ objectPointer: UInt16, body: [UInt16]) -> STObject {
    let object = STObject(size: 1, oddBytes: 0, isPointers: false, inClass: OOPS.ClassFloatPointer)
    var value: Word = 0
    if body.count == 2 {
      value = (Word(body[1]) << 16) | Word(body[0])
    }
    object.body[0] = value
    return object
  }

  func cantBeIntegerObject(_ objectPointer: OOP) throws {
    if isIntegerObject(objectPointer) {
      // TODO fix up to raise error to user
      fatalError("A small integer has no object table entry")
    }
  }
  // WARNING: force unwrapping of object table
  // if the code is bug free, then this will always work!
  func countOf(_ objectPointer: OOP) -> Word {
    return memory[objectPointer]!.count
  }
  func countOf(_ objectPointer: OOP, put value: Word) {
    memory[objectPointer]!.count = value
  }
  func oddBytesOf(_ objectPointer: OOP) -> Int {
    return memory[objectPointer]!.object.oddBytes
  }
  func oddBytesOf(_ objectPointer: OOP, put value: Int) {
    memory[objectPointer]!.object.oddBytes = value
  }
  func isPointers(_ objectPointer: OOP) -> Bool {
    return memory[objectPointer]!.object.isPointers
  }
  func isPointers(_ objectPointer: OOP, put value: Bool) {
    memory[objectPointer]!.object.isPointers = value
  }
  func sizeOf(_ objectPointer: OOP) -> Int {
    return memory[objectPointer]!.object.size()
  }
  func classOf(_ objectPointer: OOP) -> OOP {
    return memory[objectPointer]!.object.classOop
  }
  func heapChunkOf(_ objectPointer: OOP, word offset: Int) -> Word {
    return memory[objectPointer]!.object.body[offset]
  }
  func heapChunkOf(_ objectPointer: OOP, word offset: Int, put value: Word) {
    memory[objectPointer]!.object.body[offset] = value
  }
  func heapChunkOf(_ objectPointer: OOP, byte offset: Int) -> Byte {
    let word = offset / BytesPerWord
    let byteNum = offset % BytesPerWord
    let value = memory[objectPointer]!.object.body[word] & ByteMasks[byteNum]
    return Byte(value >> ByteShifts[byteNum])
  }
  func heapChunkOf(_ objectPointer: OOP, byte offset: Int, put value: Byte) {
    let word = offset / BytesPerWord
    let byteNum = offset % BytesPerWord
    let oldValue = memory[objectPointer]!.object.body[word] & ~ByteMasks[byteNum]
    let newValue = Word(value & 0xFF) << ByteShifts[byteNum]
    memory[objectPointer]!.object.body[word] = oldValue | newValue
  }
  func lastPointerOf(_ objectPointer: OOP) -> Int {
    if isPointers(objectPointer) {
      return sizeOf(objectPointer)
    }
    if classOf(objectPointer) != OOPS.ClassCompiledMethod {
      return 0
    }
    let methodHeader = Int(heapChunkOf(objectPointer, word: 0))
    return 1 + ((methodHeader & 126) >> 1)
  }
  func allocate(_ size: Int, oddBytes: Int, isPointers: Bool, forClass classOop: OOP) -> OOP {
    countUp(classOop)
    let objectPointer = DictionaryObjectMemory.nextAvailableOop()
    let object = STObject(size: size, oddBytes: oddBytes, isPointers: isPointers, inClass: classOop)
    memory[objectPointer] = ObjectTableEntry(forObject: object)
    return objectPointer
  }
  func deallocate(_ objectPointer: OOP) {
    memory[objectPointer] = nil
  }
  func countUp(_ objectPointer: OOP) {
    if isIntegerObject(objectPointer) {
      // integer objects have special encoding
      return
    }
    countOf(objectPointer, put: countOf(objectPointer)+1)
  }
  func countDown(_ rootObjectPointer: OOP) {
    if isIntegerObject(rootObjectPointer) {
      // integer objects have special encoding
      return
    }
    forAllObjectsAccessibleFrom(rootObjectPointer,
      suchThat: { oop in let count = countOf(oop)-1 ; countOf(oop, put: count) ; return count == 0 },
      do: { oop in countOf(oop, put: 0) ; deallocate(oop) })
  }
  func forAllObjectsAccessibleFrom(_ objectPointer: OOP, suchThat predicate: (OOP)->Bool, do action: (OOP)->Void) {
    if predicate(objectPointer) {
      forAllOtherObjectsAccessibleFrom(objectPointer, suchThat: predicate, do: action)
    }
  }
  func forAllOtherObjectsAccessibleFrom(_ objectPointer: OOP, suchThat predicate: (OOP)->Bool, do action: (OOP)->Void) {
    // Handle the class
    guard let object = memory[objectPointer]?.object else {
      // TODO: raise error to user
      fatalError("reference to non-existing object at oop \(objectPointer)")
    }
    if predicate(object.classOop) {
      // Should never get here!
      forAllOtherObjectsAccessibleFrom(object.classOop, suchThat: predicate, do: action)
    }
    var offset = 0
    while offset <= lastPointerOf(objectPointer)-1 {
      let next = heapChunkOf(objectPointer, word: offset)
      if !isIntegerObject(next) && predicate(next) {
        forAllOtherObjectsAccessibleFrom(next, suchThat: predicate, do: action)
      }
      offset += 1
    }
    action(objectPointer)
  }
  func reclaimInaccessibleObjects() {
    zeroReferenceCounts()
    markAccessibleObjects()
    rectifyCountsAndDealtocateGarbage()
  }
  func zeroReferenceCounts() {
    for (_, tableEntry) in memory {
      tableEntry.count = 0
    }
  }
  func markAccessibleObjects() {
    for rootObjectPointer in DictionaryObjectMemory.RootObjects {
      markObjectsAccessibleFrom(rootObjectPointer)
    }
  }
  func markObjectsAccessibleFrom(_ rootObjectPointer: OOP) {
    forAllObjectsAccessibleFrom(rootObjectPointer,
      suchThat: { oop in let unmarked = countOf(oop)==0 ; if unmarked { countOf(oop, put: 1) } ; return unmarked },
      do: { oop in countOf(oop, put: 1) })
  }
  func rectifyCountsAndDealtocateGarbage() {
    let allObjectPointers = memory.keys
    for objectPointer in allObjectPointers {
      let tableEntry = memory[objectPointer]!
      if tableEntry.count == 0 {
        deallocate(objectPointer)
        continue
      }
      countOf(objectPointer, put: countOf(objectPointer)-1)
      countUp(tableEntry.object.classOop)
      var offset = 0
      while offset <= lastPointerOf(objectPointer)-1 {
        let next = heapChunkOf(objectPointer, word: offset)
        countUp(next)
        offset += 1
      }
    }
    for rootObjectPointer in DictionaryObjectMemory.RootObjects {
      countUp(rootObjectPointer)
    }
    countOf(OOPS.NilPointer, put: Word.max)
  }
  func fetchPointer(_ fieldIndex: Int, ofObject objectPointer: OOP) -> OOP {
    return heapChunkOf(objectPointer, word: fieldIndex)
  }
  func storePointer(_ fieldIndex: Int, ofObject objectPointer: OOP, withValue valuePointer: OOP) {
    countUp(valuePointer)
    countDown(heapChunkOf(objectPointer, word: fieldIndex))
    heapChunkOf(objectPointer, word: fieldIndex, put: valuePointer)
  }
  func fetchWord(_ wordIndex: Int, ofObject objectPointer: OOP) -> Word {
    return heapChunkOf(objectPointer, word: wordIndex)
  }
  func storeWord(_ wordIndex: Int, ofObject objectPointer: OOP, withValue valueWord: Word) {
    heapChunkOf(objectPointer, word: wordIndex, put: valueWord)
  }
  func fetchByte(_ byteIndex: Int, ofObject objectPointer: OOP) -> Byte {
    return heapChunkOf(objectPointer, byte: byteIndex)
  }
  func storeByte(_ byteIndex: Int, ofObject objectPointer: OOP, withValue valueByte: Byte) {
    heapChunkOf(objectPointer, byte: byteIndex, put: valueByte)
  }
  func increaseReferencesTo(_ objectPointer: OOP) {
    countUp(objectPointer)
  }
  func decreaseReferencesTo(_ objectPointer: OOP) {
    countDown(objectPointer)
  }
  func fetchClassOf(_ objectPointer: OOP) -> OOP {
    if isIntegerObject(objectPointer) {
      return OOPS.ClassSmallInteger
    }
    return classOf(objectPointer)
  }
  func fetchWordLengthOf(_ objectPointer: OOP) -> Int {
    return sizeOf(objectPointer)
  }
  func fetchByteLengthOf(_ objectPointer: OOP) -> Int {
    return (sizeOf(objectPointer) * BytesPerWord) - oddBytesOf(objectPointer)
  }
  func instantiateClass(_ classPointer: OOP, withPointers length: Int) -> OOP {
    return allocate(length, oddBytes: 0, isPointers: true, forClass: classPointer)
  }
  func instantiateClass(_ classPointer: OOP, withWords length: Int) -> OOP {
    return allocate(length, oddBytes: 0, isPointers: false, forClass: classPointer)
  }
  func instantiateClass(_ classPointer: OOP, withBytes length: Int) -> OOP {
    let size = (length + BytesPerWord - 1) / BytesPerWord
    let extra = length % BytesPerWord
    let oddBytes = (extra == 0) ? 0 : (BytesPerWord - extra)
    return allocate(size, oddBytes: oddBytes, isPointers: false, forClass: classPointer)
  }
  func swapPointersOf(_ firstPointer: OOP, and secondPointer: OOP) {
    let firstObject = memory[firstPointer]!.object
    let secondObject = memory[secondPointer]!.object
    memory[firstPointer]!.object = secondObject
    memory[secondPointer]!.object = firstObject
  }
  func integerValueOf(_ objectPointer: OOP) -> SignedWord {
    return SignedWord(bitPattern: objectPointer) >> 1
  }
  func integerObjectOf(_ value: SignedWord) -> OOP {
    return OOP(bitPattern: value << 1) | 1
  }
  func isIntegerObject(_ objectPointer: OOP) -> Bool {
    return (objectPointer & 1) == 1
  }
  func isIntegerValue(_ valueWord: SignedWord) -> Bool {
    return (valueWord >= MinInt) && (valueWord <= MaxInt)
  }
}
