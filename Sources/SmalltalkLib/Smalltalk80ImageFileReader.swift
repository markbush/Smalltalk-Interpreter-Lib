import Foundation

class Smalltalk80ImageFileReader : ImageFileReader {
  let data: Data
  let bigEndian: Bool
  let ObjectSpaceStart = 512
  let ObjectTableStart: Int
  let ObjectTableWords: UInt16

  init(_ data: Data) {
    self.data = data
    // Standard image file should be big endian, but the version found in some
    // implementations are little endian!
    // The first 4 bytes are the object space size in words
    // A word is 2 bytes in a standard Smalltalk-80 image
    // The original image of 1983 was about 500k bytes (250k words)
    // with the first bytes being (in hex): 00 03 F3 40
    // It is not possible to use this to determine endian-ness since a modified
    // image could end up with these bytes as: 00 04 04 00
    // The next 4 bytes are the size of the object table in words
    // The original image has these (in hex) as: 00 00 97 50
    // The maximum object table size with 2 byte words is 65534 words (since
    // the last word was a free list pointer) so bytes 4 & 5 should be zero
    // in a big endian system
    self.bigEndian = (data[4] == 0) && (data[5] == 0)
    let objectSpaceWords: UInt32 = bigEndian ?
      (UInt32(data[0])<<24) | (UInt32(data[1])<<16) | (UInt32(data[2])<<8) | UInt32(data[3]) :
      (UInt32(data[3])<<24) | (UInt32(data[2])<<16) | (UInt32(data[1])<<8) | UInt32(data[0])
    // Object table starts on a 512 byte boundary
    self.ObjectTableStart = (ObjectSpaceStart + (Int(objectSpaceWords)*2) + 511) / 512 * 512
    self.ObjectTableWords = bigEndian ? (UInt16(data[6])<<8) | UInt16(data[7]) : (UInt16(data[5])<<8) | UInt16(data[4])
  }

  func loadInto(_ memory: ObjectMemory) {
    // 2 words per object table entry
    let numObjectTableEntries = ObjectTableWords / 2
    for i in 0 ..< numObjectTableEntries {
      let objectPoineter = UInt16(i * 2)
      readTableEntryFor(objectPoineter, into: memory)
    }
  }

  func readTableEntryFor(_ objectPointer: UInt16, into memory: ObjectMemory) {
    let dataOffset = ObjectTableStart + (Int(objectPointer) * 2)
    let flags: UInt8 = (readByte(dataOffset) & 0xF0) >> 4
    guard (flags & 0x02) != 0x02 else {
      // free bit set so ignore
      return
    }
    let segment: UInt8 = readByte(dataOffset) & 0x0F
    let count: UInt8 = readByte(dataOffset+1)
    let location: UInt16 = readWord(dataOffset+2)
    let objectSpaceOffsetWord: UInt32 = (UInt32(segment) << 16) | UInt32(location)
    let objectSpaceOffset = ObjectSpaceStart + Int(objectSpaceOffsetWord * 2)
    let size: Int = Int(readWord(objectSpaceOffset))
    let classPointer: UInt16 = readWord(objectSpaceOffset+2)
    let body: [UInt16] = (0 ..< size-2).map { i in readWord(objectSpaceOffset + 4 + (2*i)) }
    let isPointers = (flags & 0x04) == 0x04
    let isOdd = (flags & 0x08) == 0x08
    memory.addObjectFromStandardImage(objectPointer, inClass: classPointer, withCount: count, isPointers: isPointers, isOdd: isOdd, body: body)
  }

  func readByte(_ position: Int) -> UInt8 {
    return data[position]
  }
  func readWord(_ position: Int) -> UInt16 {
    if bigEndian {
      return (UInt16(data[position]) << 8) | UInt16(data[position+1])
    } else {
      return (UInt16(data[position+1]) << 8) | UInt16(data[position])
    }
  }
}
