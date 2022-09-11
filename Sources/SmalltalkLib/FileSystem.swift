import Foundation

class FileSystem {
  let EOK: SignedWord = 0
  let EBADF: SignedWord = 9
  let EINVAL: SignedWord = 22

  var fileHandles: [Int32:FileHandle] = [:]
  var lastError: SignedWord = 0

  func errorText(_ code: SignedWord) -> String {
    switch lastError {
    case EOK: return "all ok"
    case EINVAL: return "invalid argument"
    case EBADF: return "bad file number"
    default: return "unknown error"
    }
  }
  func tell(_ fd: Int32) -> UInt64 {
    lastError = EOK
    guard let fileHandle = fileHandles[fd] else {
      lastError = EBADF
      return 0
    }
    do {
      let position = try fileHandle.offset()
      return position
    } catch {
      lastError = EINVAL
      return 0
    }
  }
  @discardableResult func seek(_ fd: Int32, to position: UInt64) -> Bool {
    lastError = EOK
    guard let fileHandle = fileHandles[fd] else {
      lastError = EBADF
      return false
    }
    do {
      try fileHandle.seek(toOffset: position)
      let actualPosition = try fileHandle.offset()
      return actualPosition == position
    } catch {
      lastError = EINVAL
      return false
    }
  }
  func read(_ fd: Int32, upToCount count: Int) -> Data? {
    lastError = EOK
    guard let fileHandle = fileHandles[fd] else {
      lastError = EBADF
      return nil
    }
    do {
      let data = try fileHandle.read(upToCount: count) ?? Data()
      return data
    } catch {
      lastError = EINVAL
      return nil
    }
  }
  func write(_ fd: Int32, from buffer: [UInt8]) -> Bool {
    lastError = EOK
    guard let fileHandle = fileHandles[fd] else {
      lastError = EBADF
      return false
    }
    do {
      try fileHandle.write(contentsOf: buffer)
      return true
    } catch {
      lastError = EINVAL
      return false
    }
  }
  func truncate(_ fd: Int32, to size: UInt64) -> Bool {
    lastError = EOK
    guard let fileHandle = fileHandles[fd] else {
      lastError = EBADF
      return false
    }
    do {
      try fileHandle.truncate(atOffset: size)
      return true
    } catch {
      lastError = EINVAL
      return false
    }
  }
  func fileSize(_ fd: Int32) -> UInt64? {
    lastError = EOK
    guard let fileHandle = fileHandles[fd] else {
      lastError = EBADF
      return nil
    }
    do {
      let position = try fileHandle.offset()
      let size = try fileHandle.seekToEnd()
      try fileHandle.seek(toOffset: position)
      return size
    } catch {
      lastError = EINVAL
      return nil
    }
  }
  func openFile(_ fileName: String) -> Int32 {
    lastError = EOK
    if let fileHandle = FileHandle(forUpdatingAtPath: fileName) {
      let fd = fileHandle.fileDescriptor
      fileHandles[fd] = fileHandle
      return fd
    }
    lastError = EINVAL
    return -1
  }
  @discardableResult func closeFile(_ fd: Int32) -> Int {
    lastError = EOK
    guard let fileHandle = fileHandles[fd] else {
      lastError = EBADF
      return -1
    }
    do {
      try fileHandle.close()
      fileHandles[fd] = nil
      return 0
    } catch {
      lastError = EINVAL
      return -1
    }
  }
  func createFile(_ fileName: String) -> Int32 {
    lastError = EOK
    if !FileManager.default.createFile(atPath: fileName, contents: nil) {
      lastError = EINVAL
      return -1
    }
    if let fileHandle = FileHandle(forUpdatingAtPath: fileName) {
      let fd = fileHandle.fileDescriptor
      fileHandles[fd] = fileHandle
      return fd
    }
    lastError = EINVAL
    return -1
  }
  func deleteFile(_ fileName: String) -> Bool {
    lastError = EOK
    do {
      try FileManager.default.removeItem(atPath: fileName)
      return true
    } catch {
      lastError = EINVAL
      return false
    }
  }
  func renameFile(_ oldPath: String, to newPath: String) -> Bool {
    lastError = EOK
    do {
      try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
      return true
    } catch {
      lastError = EINVAL
      return false
    }
  }
  func fileNames() -> [String] {
    lastError = EOK
    do {
      let files = try FileManager.default.contentsOfDirectory(atPath: ".")
      return files
    } catch {
      lastError = EINVAL
      return []
    }
  }
}
