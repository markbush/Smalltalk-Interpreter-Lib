class STObject : CustomStringConvertible {
  static let BytesPerWord = MemoryLayout<Word>.size
  let classOop: OOP
  var body: [Word]
  // number of bytes not used in the last Word of this object
  var oddBytes: Int = 0
  var isPointers: Bool = false

  var description: String {
    return "STObject(oddBytes: \(oddBytes), isPointers: \(isPointers), class: \(classOop))\n  Body: \(body)\n  Bytes: \(bytes())\n  String: \(asString())"
  }
  subscript(index: Int) -> Word {
    get {
      body[index]
    }
    set(newValue) {
      body[index] = newValue
    }
  }

  init(size: Int, oddBytes: Int, isPointers: Bool, inClass classOop: OOP) {
    self.classOop = classOop
    let defaultValue = isPointers ? OOPS.NilPointer : 0
    self.body = [Word](repeating: defaultValue, count: size)
    self.oddBytes = oddBytes
    self.isPointers = isPointers
  }

  func size() -> Int {
    return body.count
  }

  func bytes() -> [UInt8] {
    if isPointers {
      return []
    }
    let byteSize = (body.count * STObject.BytesPerWord) - oddBytes
    var bytes = [UInt8](repeating: 0, count: byteSize)
    for i in 0 ..< byteSize {
      let wordNum = i / STObject.BytesPerWord
      let byteNum = i % STObject.BytesPerWord
      let shift = (STObject.BytesPerWord - byteNum - 1) * 8
      let value = (body[wordNum] >> shift) & 0xFF
      bytes[i] = UInt8(value)
    }
    return bytes
  }

  func asString() -> String {
    if isPointers {
      return ""
    }
    if let result = String(bytes: bytes(), encoding: .utf8) {
      return result
    }
    return ""
  }
  func asFloat() -> Float {
    if classOop != OOPS.ClassFloatPointer || body.count != 1 {
      return 0
    }
    return Float(bitPattern: body[0])
  }
}
