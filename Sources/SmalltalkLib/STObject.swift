import Foundation

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
    if classOop == OOPS.ClassCharacterPointer {
      return body.map { value in UInt8((value / 2) & 0xFF) }
    }
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

  func integerString() -> String {
    var result = ""
    let bytes = bytes()
    var i = bytes.count
    if i == 0 {
      return "0 <empty>"
    }
    var digits = [Int](repeating: 0, count: i * 8)
    var pos = 0
    var dest = [Int](repeating: 0, count: i)
    var source = bytes.map { x in Int(x) }
    while i > 1 {
      var rem = 0
      var j = i
      while j > 0 {
        let t = (rem << 8) + source[j - 1]
        dest[j - 1] = t / 10
        rem = t % 10
        j -= 1
      }
      pos += 1
      digits[pos - 1] = rem
      source = dest
      if source[i - 1] == 0 {
        i -= 1
      }
    }
    result += String(dest[0])
    while pos > 0 {
      result += String(digits[pos - 1])
      pos -= 1
    }
    return result
  }

  func asString() -> String {
    switch classOop {
    case OOPS.ClassFloatPointer: return "\(asFloat())"
    case OOPS.ClassLargePositiveIntegerPointer, OOPS.ClassLargeNegativeIntegerPointer:
      let prefix = (classOop == OOPS.ClassLargeNegativeIntegerPointer) ? "-" : ""
      let bytes = bytes()
      let hexBytes = bytes.map { b in String(b, radix: 16) }
      return prefix + integerString() + " \(bytes) [\(hexBytes.joined(separator: ", "))]"
    default: break
    }
    if isPointers && classOop != OOPS.ClassCharacterPointer {
      return ""
    }
    if let result = String(bytes: bytes(), encoding: .utf8) {
      switch classOop {
      case OOPS.ClassCharacterPointer: return "$"+result
      case OOPS.ClassStringPointer: return result
      case OOPS.ClassSymbolPointer: return "#"+result
      default: return ""
      }
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
