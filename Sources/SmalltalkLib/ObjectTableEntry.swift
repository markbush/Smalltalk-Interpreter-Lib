class ObjectTableEntry : CustomStringConvertible {
  // reference count
  var count: Word = 0
  var object: STObject

  var description: String {
    return "Count: \(count), Object: \(object)"
  }

  init(forObject object: STObject) {
    self.object = object
  }
}
