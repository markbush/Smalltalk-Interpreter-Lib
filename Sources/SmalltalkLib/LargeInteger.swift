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
  init() {
    self.bytes = []
    self.negative = false
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
  func lastDigit() -> UInt8 {
    if bytes.count == 0 {
      return 0
    } else {
      return bytes[bytes.count - 1]
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
  func isZero() -> Bool {
    return (bytes.count == 0) || ((bytes.count == 1) && bytes[0] == 0)
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
  func multiply(_ arg: LargeInteger) -> LargeInteger {
    return digitMultiply(arg, neg: (negative != arg.negative))
  }
  func divide(_ arg: LargeInteger) -> LargeInteger? {
    let (quo, rem) = digitDiv(arg, neg: (negative != arg.negative))
    if rem.isZero() {
      quo.truncate()
      return quo
    }
    return nil
  }
  func quo(_ arg: LargeInteger) -> LargeInteger {
    let (quo, _) = digitDiv(arg, neg: (negative != arg.negative))
    if (quo.lastDigit() == 0) && (quo.bytes.count >= 2) {
      quo.bytes.removeLast()
    }
    quo.truncate()
    return quo
  }
  func div(_ arg: LargeInteger) -> LargeInteger {
    if isZero() {
      return self
    }
    var q = quo(arg)
    var truncateDown = false
    if q.negative {
      truncateDown = !q.multiply(arg).equals(self)
    } else {
      truncateDown = q.isZero() && (negative != arg.negative)
    }
    if truncateDown {
      q = q.subtract(LargeInteger([1], negative: false))
    }
    return q
  }
  func mod(_ arg: LargeInteger) -> LargeInteger {
    return subtract(div(arg).multiply(arg))
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
  func digitMultiply(_ arg: LargeInteger, neg ng: Bool) -> LargeInteger {
    if (arg.digitAt(1) == 0) && (arg.bytes.count <= 1) {
      return LargeInteger()
    }
    let pl = bytes.count + arg.bytes.count
    let prod = LargeInteger(pl, negative: ng)
    for i in 1 ... bytes.count {
      let digit = Int(digitAt(i))
      if digit == 0 {
        continue
      }
      var k = i
      var carry = 0
      let xh = digit >> 4
      let xl = digit & 0xf
      for j in 1 ... arg.bytes.count {
        let high = Int(arg.digitAt(j)) * xh
        let low = (Int(arg.digitAt(j)) * xl) + ((high & 0xf) << 4) + carry + Int(prod.digitAt(k))
        carry = (high >> 4) + (low >> 8)
        prod.digitAt(k, put: UInt8(low & 0xff))
        k += 1
      }
      prod.digitAt(k, put: UInt8(carry))
    }
    if prod.digitAt(pl) == 0 {
      prod.bytes.removeLast()
    }
    prod.truncate()
    return prod
  }
  func highBit(_ byte: UInt8) -> Int {
    if byte == 0 {
      return 0
    }
    var i = 1
    var bit = 1
    let value = Int(byte)
    while value > bit {
      i += 1
      bit = bit + bit + 1
    }
    return i
  }
  func digitDiv(_ arg: LargeInteger, neg ng: Bool) -> (LargeInteger,LargeInteger) {
    var l = bytes.count - arg.bytes.count + 1
    if l <= 0 {
      return (LargeInteger(), self)
    }
    let d = 8 - highBit(arg.lastDigit())
    var rem = digitLshift(d, bytes: 0, lookFirst: false)
    let div = arg.digitLshift(d, bytes: 0, lookFirst: false)
    let quo = LargeInteger(l, negative: ng)
    let dl = div.bytes.count - 1
    let ql = l
    let dh = Int(div.digitAt(dl))
    let dnh = (dl == 1) ? 0 : Int(div.digitAt(dl - 1))
    var qlo = 0
    var qhi = 0
    var t = 0
    var hi = 0
    var lo = 0
    var r3 = 0
    func hiCondition() -> Bool {
      if !((t < hi) || ((t == hi) && (r3 < lo))) {
        return false
      }
      qlo -= 1
      lo -= dnh
      if lo < 0 {
        hi -= 1
        lo += 0x100
      }
      return hi >= dh
    }
    for k in 1 ... ql {
      let j = rem.bytes.count + 1 - k
      let remJ = Int(rem.digitAt(j))
      if remJ == dh {
        qlo = 15
        qhi = 15
      } else {
        let remJ1 = Int(rem.digitAt(j - 1))
        t = (remJ << 4) + (remJ1 >> 4)
        qhi = t / dh
        t = ((t % dh) << 4) + (remJ1 & 0xf)
        qlo = t / dh
        t = t % dh
        hi = qhi * dnh
        lo = (qlo * dnh) + ((hi & 0xf) << 4)
        hi = (hi >> 4) + (lo >> 8)
        lo = lo & 0xff
        r3 = (j < 3) ? 0 : Int(rem.digitAt(j - 2))
        while hiCondition() {
          hi -= dh
        }
        if qlo < 0 {
          qhi -= 1
          qlo += 0x10
        }
      }
      l = j - dl
      var a = 0
      for i in 1 ... div.bytes.count {
        hi = Int(div.digitAt(i)) * qhi
        lo = a + Int(rem.digitAt(l)) - ((hi & 0xf) << 4) - (Int(div.digitAt(i)) * qlo)
        rem.digitAt(l, put: UInt8(lo & 0xff))
        a = (lo >> 8) - (hi >> 4)
        l += 1
      }
      if a < 0 {
        qlo -= 1
        l = j - dl
        a = 0
        for i in 1 ... div.bytes.count {
          a = (a >> 8) + Int(rem.digitAt(l)) + Int(div.digitAt(i))
          rem.digitAt(l, put: UInt8(a & 0xff))
          l += 1
        }
      }
      quo.digitAt(quo.bytes.count + 1 - k, put: UInt8((qhi << 4) + qlo))
    }
    rem = rem.digitRshift(d, bytes: 0, lookFirst: dl)
    return (quo, rem)
  }
  func digitLshift(_ n: Int, bytes b: Int, lookFirst a: Bool) -> LargeInteger {
    var x = 0
    let f = n - 8
    let m = 0xff << (0 - n)
    var len = bytes.count + 1 + b
    if a {
      if (Int(lastDigit()) << f) == 0 {
        len -= 1
      }
    }
    let r = LargeInteger(len, negative: negative)
    for i in 1 ... (len - b) {
      let digit = Int(digitAt(i))
      let value = UInt8(((digit & m) << n) | x)
      r.digitAt(i + b, put: value)
      x = digit << f
    }
    return r
  }
  func digitRshift(_ anInteger: Int, bytes b: Int, lookFirst a: Int) -> LargeInteger {
    let n = 0 - anInteger
    var x = 0
    let f = n + 8
    var i = a
    let m = 0xff << (0 - f)
    var digit = Int(digitAt(i))
    while (((digit << n) | x) == 0) && (i != 1) {
      x = digit << f
      i -= 1
      digit = Int(digitAt(i))
    }
    if i <= b {
      return LargeInteger()
    }
    let r = LargeInteger(i - b, negative: negative)
    let count = i
    x = Int(digitAt(b + 1)) << n
    for i in (b + 1) ... count {
      digit = Int(digitAt(i + 1))
      let value = UInt8(((digit & m) << f) | x)
      r.digitAt(i - b, put: value)
      x = digit << n
    }
    return r
  }
}
