import Foundation

class InstanceList {
  var instances: [OOP] = []
  var lastAccess = Date()

  func initialInstance() -> OOP {
    lastAccess = Date()
    if instances.count > 0 {
      return instances[0]
    }
    return OOPS.NilPointer
  }
  func instanceAfter(_ objectPointer: OOP) -> OOP {
    lastAccess = Date()
    if let index = instances.firstIndex(of: objectPointer), index < instances.count - 1 {
      return instances[index+1]
    }
    return OOPS.NilPointer
  }
}
