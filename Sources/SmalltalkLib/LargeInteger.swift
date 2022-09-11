import Foundation

class LargeInteger : CustomStringConvertible {
  static let BytesPerWord = MemoryLayout<Word>.size
  var bytes: [UInt8]
  let negative: Bool

  var description: String {
    let values = bytes.reversed().map { x in String(format: "%02x", x)}
    let sign = negative ? "-" : "+"
    return "LargeInteger: \(sign)\(values)"
  }

  init(_ bytes: [UInt8], negative: Bool) {
    self.bytes = bytes
    self.negative = negative
    truncate()
  }
  init(_ len: Int, negative: Bool) {
    self.bytes = [UInt8](repeating: 0, count: len)
    self.negative = negative
  }
  func digitAt(_ index: Int) -> UInt8 {
    if index >= 1 && index <= bytes.count {
      return bytes[index - 1]
    }
    return 0
  }
  func digitAt(_ index: Int, put value: UInt8) {
    if index >= 1 && index <= bytes.count {
      bytes[index - 1] = value
    }
  }
  func large(_ integerClass: OOP, in memory: ObjectMemory) -> OOP {
    let integer = memory.instantiateClass(integerClass, withBytes: bytes.count)
    for i in 0 ..< bytes.count {
      memory.storeByte(i, ofObject: integer, withValue: bytes[i])
    }
    return integer
  }
  func asObjectIn(_ memory: ObjectMemory) -> OOP {
    truncate()
    if bytes.count == 0 {
      return OOPS.ZeroPointer
    }
    let integerClass = negative ? OOPS.ClassLargeNegativeIntegerPointer : OOPS.ClassLargePositiveIntegerPointer
    if bytes.count > LargeInteger.BytesPerWord {
      return large(integerClass, in: memory)
    }
    var integerValue: Int = 0
    for i in 0 ..< bytes.count {
      integerValue = integerValue + (Int(bytes[i]) << (8 * i))
    }
    if negative {
      integerValue = 0 - integerValue
    }
    if integerValue > Int(SignedWord.min) && integerValue < Int(SignedWord.max) {
      if memory.isIntegerValue(SignedWord(integerValue)) {
        return memory.integerObjectOf(SignedWord(integerValue))
      }
    }
    return large(integerClass, in: memory)
  }
  func truncate() {
    var count = bytes.count
    while count > 0 && bytes[count - 1] == 0 {
      count -= 1
    }
    if count != bytes.count {
      bytes.removeLast(bytes.count - count)
    }
  }
  func add(_ arg: LargeInteger) -> LargeInteger {
    if negative == arg.negative {
      return digitAdd(arg)
    } else {
      return digitSubtract(arg)
    }
  }
  func subtract(_ arg: LargeInteger) -> LargeInteger {
    if negative == arg.negative {
      return digitSubtract(arg)
    } else {
      return digitAdd(arg)
    }
  }
  func lessThan(_ arg: LargeInteger) -> Bool {
    if negative == arg.negative {
      if negative {
        return digitCompareTo(arg) > 0
      } else {
        return digitCompareTo(arg) < 0
      }
    } else {
      return negative
    }
  }
  func lessThanOrEqual(_ arg: LargeInteger) -> Bool {
    if negative == arg.negative {
      if negative {
        return digitCompareTo(arg) >= 0
      } else {
        return digitCompareTo(arg) <= 0
      }
    } else {
      return negative
    }
  }
  func greaterThan(_ arg: LargeInteger) -> Bool {
    if negative == arg.negative {
      if negative {
        return digitCompareTo(arg) < 0
      } else {
        return digitCompareTo(arg) > 0
      }
    } else {
      return arg.negative
    }
  }
  func greaterThanOrEqual(_ arg: LargeInteger) -> Bool {
    if negative == arg.negative {
      if negative {
        return digitCompareTo(arg) <= 0
      } else {
        return digitCompareTo(arg) >= 0
      }
    } else {
      return arg.negative
    }
  }
  func equals(_ arg: LargeInteger) -> Bool {
    if negative == arg.negative {
      return digitCompareTo(arg) == 0
    } else {
      return false
    }
  }
  func digitAdd(_ arg: LargeInteger) -> LargeInteger {
    var accum = 0
    let len = max(bytes.count, arg.bytes.count)
    let sum = LargeInteger(len, negative: negative)
    var i = 1
    while i <= len {
      accum = (accum >> 8) + Int(digitAt(i)) + Int(arg.digitAt(i))
      sum.digitAt(i, put: UInt8(accum & 0xff))
      i += 1
    }
    if accum > 0xff {
      sum.bytes.append(UInt8(accum >> 8))
    }
    sum.truncate()
    return sum
  }
  func digitSubtract(_ arg: LargeInteger) -> LargeInteger {
    var sl = bytes.count
    var al = arg.bytes.count
    var argLarger = false
    var larger = self
    var smaller = arg
    var ng = negative
    if sl == al {
      while (digitAt(sl) == arg.digitAt(sl)) && (sl > 1) {
        sl -= 1
      }
      al = sl
      argLarger = (digitAt(sl) < arg.digitAt(sl))
    } else {
      argLarger = (sl < al)
    }
    if argLarger {
      larger = arg
      smaller = self
      ng = !negative
      sl = al
    }
    let sum = LargeInteger(sl, negative: ng)
    var lastDigit = 1
    var z = 0
    var i = 1
    while i <= sl {
      z = z + Int(larger.digitAt(i)) - Int(smaller.digitAt(i))
      let value = UInt8(z & 0xff)
      sum.digitAt(i, put: value)
      if value != 0 {
        lastDigit = i
      }
      z = z >> 8
      i += 1
    }
    if lastDigit != sl {
      sum.bytes.removeLast(sl - lastDigit)
    }
    sum.truncate()
    return sum
  }
  func digitCompareTo(_ arg: LargeInteger) -> Int {
    var len = bytes.count
    let argLen = arg.bytes.count
    if argLen != len {
      return (argLen > len) ? -1 : 1
    }
    while len > 0 {
      let t5 = arg.digitAt(len)
      let t6 = digitAt(len)
      if t5 != t6 {
        return (t5 < t6) ? 1 : -1
      }
      len -= 1
    }
    return 0
  }
}
