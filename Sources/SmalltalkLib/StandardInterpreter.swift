import Foundation

class StandardInterpreter : Interpreter {
  let BytesPerWord = MemoryLayout<Word>.size
  // CompiledMethod constants
  let HeaderIndex = 0
  let LiteralStart = 1
  // Association constants
  let ValueIndex = 1
  // MethodContext constants
  let SenderIndex = 0
  let InstructionPointerIndex = 1
  let StackPointerIndex = 2
  let MethodIndex = 3
  let ReceiverIndex = 5
  let TempFrameStart = 6
  // BlockContext constants
  let CallerIndex = 0
  let BlockArgumentCountIndex = 3
  let InitialIPIndex = 4
  let HomeIndex = 5
  // Class constants
  let SuperclassIndex = 0
  let MessageDictionaryIndex = 1
  let InstanceSpecificationIndex = 2
  // Message dictionary constants
  let MethodArrayIndex = 1
  let SelectorStart = 2
  // Message selector constants
  let MessageSelectorIndex = 0
  let MessageArgumentsIndex = 1
  let MessageSize = 2
  // Point constants
  let XIndex = 0
  let YIndex = 1
  let ClassPointSize = 2
  // Process constants
  let SuspendedContextIndex = 1
  let PriorityIndex = 2
  let MyListIndex = 3
  // ProcessorScheduler constants
  let ProcessListsIndex = 0
  let ActiveProcessIndex = 1
  // LinkedList constants
  let FirstLinkIndex = 0
  let LastLinkIndex = 1
  // Semaphore constants
  let ExcessSignalsIndex = 2
  // Link constants
  let NextLinkIndex = 0
  // Character constants
  let CharacterValueIndex = 0
  // Stream constants
  let StreamArrayIndex = 0
  let StreamIndexIndex = 1
  let StreamReadLimitIndex = 2
  let StreamWriteLimitIndex = 3

  var logging = true
  let memory: ObjectMemory
  var success = true
  var activeContext: OOP = OOPS.NilPointer
  var homeContext: OOP = OOPS.NilPointer
  var method: OOP = OOPS.NilPointer
  var receiver: OOP = OOPS.NilPointer
  var instructionPointer = 0
  var stackPointer = 0
  var messageSelector: OOP = OOPS.NilPointer
  var argumentCount = 0
  var newMethod: OOP = OOPS.NilPointer
  var primitiveIndex = 0
  var currentBytecode: UInt8 = 0
  var newProcessWaiting = false
  var newProcess: OOP = OOPS.NilPointer
  var semaphoreList = [OOP](repeating: 0, count: 4096)
  var semaphoreIndex = -1
  var methodCacheSize = 1024
  var methodCache: [OOP] = []

  init(_ memory: ObjectMemory) {
    self.memory = memory
  }
  func initialise() {
    initializeMethodCache()
    semaphoreIndex = -1
    activeContext = firstContext()
    memory.increaseReferencesTo(activeContext)
    fetchContextRegisters()
  }

  func fetchInteger(_ fieldIndex: Int, ofObject objectPointer: OOP) -> SignedWord {
    let integerPointer = memory.fetchPointer(fieldIndex, ofObject: objectPointer)
    if memory.isIntegerObject(integerPointer) {
      return memory.integerValueOf(integerPointer)
    }
    return SignedWord(primitiveFail())
  }
  func storeInteger(_ fieldIndex: Int, ofObject objectPointer: OOP, withValue integerValue: SignedWord) {
    if !memory.isIntegerValue(integerValue) {
      primitiveFail()
      return
    }
    let integerPointer = memory.integerObjectOf(integerValue)
    memory.storePointer(fieldIndex, ofObject: objectPointer, withValue: integerPointer)
  }
  func transfer(_ count: Int, fromIndex firstFrom: Int, ofObject fromOop: OOP, toIndex firstTo: Int, ofObject toOop: OOP) {
    var fromIndex = firstFrom
    let lastFrom = firstFrom + count
    var toIndex = firstTo
    while fromIndex < lastFrom {
      let oop = memory.fetchPointer(fromIndex, ofObject: fromOop)
      memory.storePointer(toIndex, ofObject: toOop, withValue: oop)
      memory.storePointer(fromIndex, ofObject: fromOop, withValue: OOPS.NilPointer)
      fromIndex += 1
      toIndex += 1
    }
  }
  func byte(_ byteNum: Int, of anInteger: SignedWord) -> Byte {
    let value = anInteger >> ((BytesPerWord - byteNum - 1) * 8)
    return Byte(value & 0xFF)
  }
  func headerOf(_ methodPointer: OOP) -> Word {
    return memory.fetchPointer(HeaderIndex, ofObject: methodPointer)
  }
  func literal(_ offset: Int, ofMethod methodPointer: OOP) -> OOP {
    return memory.fetchPointer(LiteralStart + offset, ofObject: methodPointer)
  }
  func flagValueOf(_ methodPointer: OOP) -> Int {
    return Int((headerOf(methodPointer) & 0xE000) >> 13)
  }
  func temporaryCountOf(_ methodPointer: OOP) -> Int {
    return Int((headerOf(methodPointer) & 0x1F00) >> 8)
  }
  func largeContextFlagOf(_ methodPointer: OOP) -> Int {
    return Int((headerOf(methodPointer) & 0x0080) >> 7)
  }
  func literalCountOf(_ methodPointer: OOP) -> Int {
    return literalCountOfHeader(headerOf(methodPointer))
  }
  func literalCountOfHeader(_ headerPointer: OOP) -> Int {
    return Int((headerPointer & 0x7E) >> 1)
  }
  func objectPointerCountOf(_ methodPointer: OOP) -> Int {
    return literalCountOf(methodPointer) + LiteralStart
  }
  func initialInstructionPointerOfMethod(_ methodPointer: OOP) -> Int {
    return ((literalCountOf(methodPointer) + LiteralStart) * BytesPerWord) + 1
  }
  func fieldIndexOf(_ methodPointer: OOP) -> Int {
    return Int((headerOf(methodPointer) & 0x1F00) >> 8)
  }
  func headerExtensionOf(_ methodPointer: OOP) -> Word {
    let literalCount = literalCountOf(methodPointer)
    return literal(literalCount - 2, ofMethod: methodPointer)
  }
  func argumentCountOf(_ methodPointer: OOP) -> Int {
    let flagValue = flagValueOf(methodPointer)
    if flagValue < 5 {
      return flagValue
    }
    if flagValue < 7 {
      return 0
    }
    return Int((headerExtensionOf(methodPointer) & 0x3E00) >> 9)
  }
  func primitiveIndexOf(_ methodPointer: OOP) -> Int {
    let flagValue = flagValueOf(methodPointer)
    if flagValue != 7 {
      return 0
    }
    return Int((headerExtensionOf(methodPointer) & 0x01FE) >> 1)
  }
  func methodClassOf(_ methodPointer: OOP) -> OOP {
    let literalCount = literalCountOf(methodPointer)
    let association = literal(literalCount - 1, ofMethod: methodPointer)
    return memory.fetchPointer(ValueIndex, ofObject: association)
  }
  func instructionPointerOfContext(_ contextPointer: OOP) -> SignedWord {
    return fetchInteger(InstructionPointerIndex, ofObject: contextPointer)
  }
  func storeInstructionPointerValue(_ value: SignedWord, inContext contextPointer: OOP) {
    storeInteger(InstructionPointerIndex, ofObject: contextPointer, withValue: value)
  }
  func stackPointerOfContext(_ contextPointer: OOP) -> SignedWord {
    return fetchInteger(StackPointerIndex, ofObject: contextPointer)
  }
  func storeStackPointerValue(_ value: SignedWord, inContext contextPointer: OOP) {
    storeInteger(StackPointerIndex, ofObject: contextPointer, withValue: value)
  }
  func argumentCountOfBlock(_ blockPointer: OOP) -> SignedWord {
    return fetchInteger(BlockArgumentCountIndex, ofObject: blockPointer)
  }
  func fetchContextRegisters() {
    if isBlockContext(activeContext) {
      homeContext = memory.fetchPointer(HomeIndex, ofObject: activeContext)
    } else {
      homeContext = activeContext
    }
    receiver = memory.fetchPointer(ReceiverIndex, ofObject: homeContext)
    method = memory.fetchPointer(MethodIndex, ofObject: homeContext)
    instructionPointer = Int(instructionPointerOfContext(activeContext)) - 1
    stackPointer = Int(stackPointerOfContext(activeContext)) + TempFrameStart - 1
  }
  func isBlockContext(_ contextPointer: OOP) -> Bool {
    let methodOrArguments = memory.fetchPointer(MethodIndex, ofObject: contextPointer)
    return memory.isIntegerObject(methodOrArguments)
  }
  func storeContextRegisters() {
    storeInstructionPointerValue(SignedWord(instructionPointer + 1), inContext: activeContext)
    storeStackPointerValue(SignedWord(stackPointer - TempFrameStart + 1), inContext: activeContext)
  }
  func push(_ object: OOP) {
    stackPointer += 1
    memory.storePointer(stackPointer, ofObject: activeContext, withValue: object)
  }
  @discardableResult func popStack() -> OOP {
    let stackTop = memory.fetchPointer(stackPointer, ofObject: activeContext)
    stackPointer -= 1
    return stackTop
  }
  func stackTop() -> OOP {
    return memory.fetchPointer(stackPointer, ofObject: activeContext)
  }
  func stackValue(_ offset: Int) -> OOP {
    return memory.fetchPointer(stackPointer - offset, ofObject: activeContext)
  }
  func pop(_ number: Int) {
    stackPointer -= number
  }
  func unPop(_ number: Int) {
    stackPointer += number
  }
  func newActiveContext(_ aContext: OOP) {
    storeContextRegisters()
    memory.decreaseReferencesTo(activeContext)
    activeContext = aContext
    memory.increaseReferencesTo(activeContext)
    fetchContextRegisters()
  }
  func sender() -> OOP {
    memory.fetchPointer(SenderIndex, ofObject: homeContext)
  }
  func caller() -> OOP {
    memory.fetchPointer(SenderIndex, ofObject: activeContext)
  }
  func temporary(_ offset: Int) -> OOP {
    memory.fetchPointer(offset + TempFrameStart, ofObject: homeContext)
  }
  func literal(_ offset: Int) -> OOP {
    literal(offset, ofMethod: method)
  }
  func hash(_ objectPointer: OOP) -> Int {
    return Int(objectPointer >> 1)
  }
  func lookupMethodInDictionary(_ dictionary: OOP) -> Bool {
    let length = memory.fetchWordLengthOf(dictionary)
    let mask = length - SelectorStart - 1
    var index = (mask & hash(messageSelector)) + SelectorStart
    var wrapAround = false
    while true {
      let nextSelector = memory.fetchPointer(index, ofObject: dictionary)
      if nextSelector == OOPS.NilPointer {
        return false
      }
      if nextSelector == messageSelector {
        let methodArray = memory.fetchPointer(MethodArrayIndex, ofObject: dictionary)
        newMethod = memory.fetchPointer(index - SelectorStart, ofObject: methodArray)
        primitiveIndex = primitiveIndexOf(newMethod)
        return true
      }
      index += 1
      if index == length {
        if wrapAround {
          return false
        }
        wrapAround = true
        index = SelectorStart
      }
    }
  }
  @discardableResult func lookupMethodInClass(_ aClass: OOP) -> Bool {
    var currentClass = aClass
    while currentClass != OOPS.NilPointer {
      let dictionary = memory.fetchPointer(MessageDictionaryIndex, ofObject: currentClass)
      if lookupMethodInDictionary(dictionary) {
        return true
      }
      currentClass = superclassOf(currentClass)
    }
    if messageSelector == OOPS.DoesNotUnderstandSelector {
      // TODO: fix this (though it cannot happen!)
      error("Recursive not understood error encountered")
      return false
    }
    createActualMessage()
    messageSelector = OOPS.DoesNotUnderstandSelector
    return lookupMethodInClass(aClass)
  }
  func superclassOf(_ classPointer: OOP) -> OOP {
    return memory.fetchPointer(SuperclassIndex, ofObject: classPointer)
  }
  func createActualMessage() {
    let argumentArray = memory.instantiateClass(OOPS.ClassArrayPointer, withPointers: argumentCount)
    let message = memory.instantiateClass(OOPS.ClassMessagePointer, withPointers: MessageSize)
    memory.storePointer(MessageSelectorIndex, ofObject: message, withValue: messageSelector)
    memory.storePointer(MessageArgumentsIndex, ofObject: message, withValue: argumentArray)
    transfer(argumentCount, fromIndex: stackPointer - (argumentCount - 1), ofObject: activeContext,
                              toIndex: 0, ofObject: argumentArray)
    pop(argumentCount)
    push(message)
    argumentCount = 1
  }
  func instanceSpecificationOf(_ classPointer: OOP) -> Word {
    return memory.fetchPointer(InstanceSpecificationIndex, ofObject: classPointer)
  }
  func isPointers(_ classPointer: OOP) -> Bool {
    return (instanceSpecificationOf(classPointer) & 0x8000) == 0x8000
  }
  func isWords(_ classPointer: OOP) -> Bool {
    return (instanceSpecificationOf(classPointer) & 0x4000) == 0x4000
  }
  func isIndexable(_ classPointer: OOP) -> Bool {
    return (instanceSpecificationOf(classPointer) & 0x2000) == 0x2000
  }
  func fixedFieldsOf(_ classPointer: OOP) -> Int {
    return Int((instanceSpecificationOf(classPointer) & 0x0FFE) >> 1)
  }

  func error(_ message: String) {
    // TODO: fix this
    fatalError(message)
  }
  func fatal(_ message: String) {
    fatalError("\(message) in bytecode \(currentBytecode) at IP \(instructionPointer) of method \(method)")
  }
  func fetchByte() -> UInt8 {
    let byte = memory.fetchByte(instructionPointer, ofObject: method)
    instructionPointer += 1
    return byte
  }
  func interpret() {
    while true {
      cycle()
    }
  }
  func cycle() {
    checkProcessSwitch()
    currentBytecode = fetchByte()
    dispatchOnThisBytecode()
  }
  func checkProcessSwitch() {
    while semaphoreIndex > 0 {
      synchronousSignal(semaphoreList[semaphoreIndex])
      semaphoreIndex -= 1
    }
    if newProcessWaiting {
      newProcessWaiting = false
      let theActiveProcess = activeProcess()
      memory.storePointer(SuspendedContextIndex, ofObject: theActiveProcess, withValue: activeContext)
      memory.storePointer(ActiveProcessIndex, ofObject: schedulerPointer(), withValue: newProcess)
      newActiveContext(memory.fetchPointer(SuspendedContextIndex, ofObject: newProcess))
    }
  }
  func dispatchOnThisBytecode() {
    switch currentBytecode {
    case 0 ... 119: stackBytecode()
    case 120 ... 127: returnBytecode()
    case 128 ... 130: stackBytecode()
    case 131 ... 134: sendBytecode()
    case 135 ... 137: stackBytecode()
    case 144 ... 175: jumpBytecode()
    case 176 ... 255: sendBytecode()
    default: fatal("Unimplemented operation")
    }
  }
  func stackBytecode() {
    switch currentBytecode {
    case 0 ... 15: pushReceiverVariableBytecode()
    case 16 ... 31: pushTemporaryVariableBytecode()
    case 32 ... 63: pushLiteralConstantBytecode()
    case 64 ... 95: pushLiteralVariableBytecode()
    case 96 ... 103: storeAndPopReceiverVariableBytecode()
    case 104 ... 111: storeAndPopTemporaryVariableBytecode()
    case 112: pushReceiverBytecode()
    case 113 ... 119: pushConstantBytecode()
    case 128: extendedPushBytecode()
    case 129: extendedStoreBytecode()
    case 130: extendedStoreAndPopBytecode()
    case 135: popStackBytecode()
    case 136: dupticateTopBytecode()
    case 137: pushActiveContextBytecode()
    default: fatal("Impossible stack operation \(currentBytecode)")
    }
  }
  func returnBytecode() {
    switch currentBytecode {
    case 120: returnValue(receiver, to: sender())
    case 121: returnValue(OOPS.TruePointer, to: sender())
    case 122: returnValue(OOPS.FalsePointer, to: sender())
    case 123: returnValue(OOPS.NilPointer, to: sender())
    case 124: returnValue(popStack(), to: sender())
    case 125: returnValue(popStack(), to: caller())
    default: fatal("Impossible return")
    }
  }
  func returnValue(_ resultPointer: OOP, to contextPointer: OOP) {
    if contextPointer == OOPS.NilPointer {
      push(activeContext)
      push(resultPointer)
      sendSelector(OOPS.CannotReturnSelector, argumentCount: 1)
      return
    }
    let sendersIP = memory.fetchPointer(InstructionPointerIndex, ofObject: contextPointer)
    if sendersIP == OOPS.NilPointer {
      push(activeContext)
      push(resultPointer)
      sendSelector(OOPS.CannotReturnSelector, argumentCount: 1)
      return
    }
    memory.increaseReferencesTo(resultPointer)
    returnToActiveContext(contextPointer)
    push(resultPointer)
    memory.decreaseReferencesTo(resultPointer)
  }
  func returnToActiveContext(_ aContext: OOP) {
    memory.increaseReferencesTo(aContext)
    nilContextFields()
    memory.decreaseReferencesTo(activeContext)
    activeContext = aContext
    fetchContextRegisters()
  }
  func nilContextFields() {
    memory.storePointer(SenderIndex, ofObject: activeContext, withValue: OOPS.NilPointer)
    memory.storePointer(InstructionPointerIndex, ofObject: activeContext, withValue: OOPS.NilPointer)
  }
  func sendBytecode() {
    switch currentBytecode {
    case 131 ... 134: extendedSendBytecode()
    case 176 ... 207: sendSpecialSelectorBytecode()
    case 208 ... 255: sendLiteralSelectorBytecode()
    default: fatal("Impossible send operation")
    }
  }
  func jumpBytecode() {
    switch currentBytecode {
    case 144 ... 151: shortUnconditionalJump()
    case 152 ... 159: shortConditionalJump()
    case 160 ... 167: longUnconditionalJump()
    case 168 ... 175: longConditionalJump()
    default: fatal("Impossible jump operation")
    }
  }
  func pushReceiverVariableBytecode() {
    let fieldIndex = Int(currentBytecode & 0x0F)
    pushReceiverVariable(fieldIndex)
  }
  func pushReceiverVariable(_ fieldIndex: Int) {
    push(memory.fetchPointer(fieldIndex, ofObject: receiver))
  }
  func pushTemporaryVariableBytecode() {
    let fieldIndex = Int(currentBytecode & 0x0F)
    pushTemporaryVariable(fieldIndex)
  }
  func pushTemporaryVariable(_ temporaryIndex: Int) {
    push(temporary(temporaryIndex))
  }
  func pushLiteralConstantBytecode() {
    let fieldIndex = Int(currentBytecode & 0x1F)
    pushLiteralConstant(fieldIndex)
  }
  func pushLiteralConstant(_ literalIndex: Int) {
    push(literal(literalIndex))
  }
  func pushLiteralVariableBytecode() {
    let fieldIndex = Int(currentBytecode & 0x1F)
    pushLiteralVariable(fieldIndex)
  }
  func pushLiteralVariable(_ literalIndex: Int) {
    let association = literal(literalIndex)
    push(memory.fetchPointer(ValueIndex, ofObject: association))
  }
  func storeAndPopReceiverVariableBytecode() {
    let variableIndex = Int(currentBytecode & 0x07)
    memory.storePointer(variableIndex, ofObject: receiver, withValue: popStack())
  }
  func storeAndPopTemporaryVariableBytecode() {
    let variableIndex = Int(currentBytecode & 0x07)
    memory.storePointer(variableIndex + TempFrameStart, ofObject: homeContext, withValue: popStack())
  }
  func pushReceiverBytecode() {
    push(receiver)
  }
  func pushConstantBytecode() {
    switch currentBytecode {
    case 113: push(OOPS.TruePointer)
    case 114: push(OOPS.FalsePointer)
    case 115: push(OOPS.NilPointer)
    case 116: push(OOPS.MinusOnePointer)
    case 117: push(OOPS.ZeroPointer)
    case 118: push(OOPS.OnePointer)
    case 119: push(OOPS.TwoPointer)
    default: fatal("Impossible push constant")
    }
  }
  func extendedPushBytecode() {
    let descriptor = fetchByte()
    let variableType = (descriptor & 0xC0) >> 6
    let variableIndex = Int(descriptor & 0x3F)
    switch variableType {
    case 0: pushReceiverVariable(variableIndex)
    case 1: pushTemporaryVariable(variableIndex)
    case 2: pushLiteralConstant(variableIndex)
    case 3: pushLiteralVariable(variableIndex)
    default: fatal("Impossible variable type \(variableType) in extended push arg \(descriptor)")
    }
  }
  func extendedStoreBytecode() {
    let descriptor = fetchByte()
    let variableType = (descriptor & 0xC0) >> 6
    let variableIndex = Int(descriptor & 0x3F)
    switch variableType {
    case 0: memory.storePointer(variableIndex, ofObject: receiver, withValue: stackTop())
    case 1: memory.storePointer(variableIndex + TempFrameStart, ofObject: homeContext, withValue: stackTop())
      // case 2 - impossible option
    case 3:
      let association = literal(variableIndex)
      memory.storePointer(ValueIndex, ofObject: association, withValue: stackTop())
    default: fatal("Impossible variable type \(variableType) in extended store arg \(descriptor)")
    }
  }
  func extendedStoreAndPopBytecode() {
    extendedStoreBytecode()
    popStackBytecode()
  }
  func popStackBytecode() {
    popStack()
    // pop(1) ??
  }
  func dupticateTopBytecode() {
    push(stackTop())
  }
  func pushActiveContextBytecode() {
    push(activeContext)
  }
  func shortUnconditionalJump() {
    let offset = Int(currentBytecode & 0x07)
    jump(offset + 1)
  }
  func shortConditionalJump() {
    let offset = Int(currentBytecode & 0x07)
    jumpIf(OOPS.FalsePointer, by: offset+1)
  }
  func longUnconditionalJump() {
    let offset = Int(currentBytecode & 0x07)
    jump((offset-4)*256 + Int(fetchByte()))
  }
  func longConditionalJump() {
    var offset = Int(currentBytecode & 0x03)
    offset = offset*256 + Int(fetchByte())
    let condition = (currentBytecode <= 171) ? OOPS.TruePointer : OOPS.FalsePointer
    jumpIf(condition, by: offset)
  }
  func jump(_ offset: Int) {
    instructionPointer += offset
  }
  func jumpIf(_ condition: OOP, by offset: Int) {
    let boolean = popStack()
    if boolean == condition {
      jump(offset)
    } else {
      if boolean != OOPS.TruePointer && boolean != OOPS.FalsePointer {
        unPop(1)
        sendMustBeBoolean()
      }
    }
  }
  func sendMustBeBoolean() {
    sendSelector(OOPS.MustBeBooleanSelector, argumentCount: 0)
  }
  func extendedSendBytecode() {
    switch currentBytecode {
    case 131: singleExtendedSendBytecode()
    case 132: doubleExtendedSendBytecode()
    case 133: singleExtendedSuperBytecode()
    case 134: doubleExtendedSuperBytecode()
    default: fatal("Impossible extended send")
    }
  }
  func sendSpecialSelectorBytecode() {
    if !specialSelectorPrimitiveResponse() {
      let selectorIndex = Int((currentBytecode - 176) * 2)
      let selector = memory.fetchPointer(selectorIndex, ofObject: OOPS.SpecialSelectorsPointer)
      let count = Int(fetchInteger(selectorIndex + 1, ofObject: OOPS.SpecialSelectorsPointer))
      sendSelector(selector, argumentCount: count)
    }
  }
  func sendLiteralSelectorBytecode() {
    let selector = literal(Int(currentBytecode & 0x0F))
    let count = (Int(currentBytecode & 0x30) >> 4) - 1
    sendSelector(selector, argumentCount: count)
  }
  func sendSelector(_ selector: OOP, argumentCount count: Int) {
    messageSelector = selector
    argumentCount = count
    let newReceiver = stackValue(argumentCount)
    sendSelectorToClass(memory.fetchClassOf(newReceiver))
  }
  func sendSelectorToClass(_ classPointer: OOP) {
    if logging {
      let className = memory.stringValueOf(classPointer)
      let message = memory.stringValueOf(messageSelector)
      print("[SEND] \(className) >> \(message)")
    }
    findNewMethodInClass(classPointer)
    executeNewMethod()
  }
  func findNewMethodInClass(_ classPointer: OOP) {
    let hash = Int((messageSelector & classPointer & 0xFF) << 2)
    if methodCache[hash] == messageSelector && methodCache[hash+1] == classPointer {
      newMethod = methodCache[hash+2]
      primitiveIndex = Int(methodCache[hash+3])
    } else {
      lookupMethodInClass(classPointer)
      methodCache[hash] = messageSelector
      methodCache[hash+1] = classPointer
      methodCache[hash+2] = newMethod
      methodCache[hash+3] = Word(primitiveIndex)
    }
  }
  func initializeMethodCache() {
    methodCacheSize = 1024
    methodCache = [OOP](repeating: OOPS.NilPointer, count: methodCacheSize)
  }
  func executeNewMethod() {
    if !primitiveResponse() {
      activateNewMethod()
    }
  }
  func activateNewMethod() {
    // Always large contexts
    let contextSize = (largeContextFlagOf(newMethod) == 1) ? 32 + TempFrameStart : 12 + TempFrameStart
    let newContext = memory.instantiateClass(OOPS.ClassMethodContextPointer, withPointers: contextSize)
    memory.storePointer(SenderIndex, ofObject: newContext, withValue: activeContext)
    storeInstructionPointerValue(SignedWord(initialInstructionPointerOfMethod(newMethod)), inContext: newContext)
    storeStackPointerValue(SignedWord(temporaryCountOf(newMethod)), inContext: newContext)
    memory.storePointer(MethodIndex, ofObject: newContext, withValue: newMethod)
    transfer(argumentCount + 1, fromIndex: stackPointer - argumentCount, ofObject: activeContext,
                                  toIndex: ReceiverIndex, ofObject: newContext)
    pop(argumentCount + 1)
    newActiveContext(newContext)
  }
  func singleExtendedSendBytecode() {
    let descriptor = fetchByte()
    let selectorIndex = Int(descriptor & 0x1F)
    let count = Int((descriptor & 0xE0) >> 5)
    sendSelector(literal(selectorIndex), argumentCount: count)
  }
  func doubleExtendedSendBytecode() {
    let count = Int(fetchByte())
    let selector = literal(Int(fetchByte()))
    sendSelector(selector, argumentCount: count)
  }
  func singleExtendedSuperBytecode() {
    let descriptor = fetchByte()
    argumentCount = Int((descriptor & 0xE0) >> 5)
    let selectorIndex = Int(descriptor & 0x1F)
    messageSelector = literal(selectorIndex)
    let methodClass = methodClassOf(method)
    sendSelectorToClass(superclassOf(methodClass))
  }
  func doubleExtendedSuperBytecode() {
    argumentCount = Int(fetchByte())
    messageSelector = literal(Int(fetchByte()))
    let methodClass = methodClassOf(method)
    sendSelectorToClass(superclassOf(methodClass))
  }

  func success(_ successValue: Bool) {
    success = successValue && success
  }
  func initPrimitive() {
    success = true
  }
  @discardableResult func primitiveFail() -> Int {
    success = false
    return 0
  }
  func popInteger() -> SignedWord {
    let integerPointer = popStack()
    success(memory.isIntegerObject(integerPointer))
    if success {
      return memory.integerValueOf(integerPointer)
    }
    // TODO: is this ok? (success is false so value should get unpopped...)
    return 0
  }
  func pushInteger(_ integerValue: SignedWord) {
    push(memory.integerObjectOf(integerValue))
  }
  func popFloat() -> Float {
    let floatPointer = popStack()
    success(memory.fetchClassOf(floatPointer) == OOPS.ClassFloatPointer)
    if success {
      return Float(bitPattern: memory.fetchWord(0, ofObject: floatPointer))
    }
    return 0
  }
  func pushFloat(_ floatValue: Float) {
    let floatPointer = memory.instantiateClass(OOPS.ClassFloatPointer, withWords: 1)
    memory.storeWord(0, ofObject: floatPointer, withValue: floatValue.bitPattern)
    push(floatPointer)
  }
  // The Blue Book requires positive16BitIntegerFor but we support 32 bit
  // SmallIntegers so a 16bit LargePositiveInteger will never be needed.
  func positive32BitIntegerFor(_ integerValue: SignedWord) -> OOP {
    if integerValue < 0 {
      return OOP(primitiveFail())
    }
    if memory.isIntegerValue(integerValue) {
      return memory.integerObjectOf(integerValue)
    }
    let newLargeInteger = memory.instantiateClass(OOPS.ClassLargePositiveIntegerPointer, withBytes: 4)
    memory.storeByte(0, ofObject: newLargeInteger, withValue: byte(0, of: integerValue))
    memory.storeByte(1, ofObject: newLargeInteger, withValue: byte(1, of: integerValue))
    memory.storeByte(2, ofObject: newLargeInteger, withValue: byte(2, of: integerValue))
    memory.storeByte(3, ofObject: newLargeInteger, withValue: byte(3, of: integerValue))
    return newLargeInteger
  }
  func positive32BitValueOf(_ integerPointer: OOP) -> SignedWord {
    if memory.isIntegerObject(integerPointer) {
      return memory.integerValueOf(integerPointer)
    }
    if memory.fetchClassOf(integerPointer) != OOPS.ClassLargePositiveIntegerPointer {
      return SignedWord(primitiveFail())
    }
    if memory.fetchByteLengthOf(integerPointer) != 4 {
      return SignedWord(primitiveFail())
    }
    var value = SignedWord(memory.fetchByte(3, ofObject: integerPointer))
    value = (value << 8) | SignedWord(memory.fetchByte(2, ofObject: integerPointer))
    value = (value << 8) | SignedWord(memory.fetchByte(1, ofObject: integerPointer))
    value = (value << 8) | SignedWord(memory.fetchByte(0, ofObject: integerPointer))
    return value
  }
  func specialSelectorPrimitiveResponse() -> Bool {
    initPrimitive()
    if currentBytecode <= 191 {
      arithmeticSelectorPrimitive()
    } else {
      commonSelectorPrimitive()
    }
    return success
  }
  func arithmeticSelectorPrimitive() {
    success(memory.isIntegerObject(stackValue(1)))
    if !success {
      return
    }
    switch currentBytecode {
    case 176: primitiveAdd()
    case 177: primitiveSubtract()
    case 178: primitiveLessThan()
    case 179: primitiveGreaterThan()
    case 180: primitiveLessOrEqual()
    case 181: primitiveGreaterOrEqual()
    case 182: primitiveEqual()
    case 183: primitiveNotEqual()
    case 184: primitiveMultiply()
    case 185: primitiveDivide()
    case 186: primitiveMod()
    case 187: primitiveMakePoint()
    case 188: primitiveBitShift()
    case 189: primitiveDiv()
    case 190: primitiveBitAnd()
    case 191: primitiveBitOr()
    default: primitiveFail()
    }
  }
  func commonSelectorPrimitive() {
    let count = (Int(currentBytecode) - 176) * 2 + 1
    argumentCount = Int(fetchInteger(count, ofObject: OOPS.SpecialSelectorsPointer))
    let receiverClass = memory.fetchClassOf(stackValue(argumentCount))
    switch currentBytecode {
    case 198: primitiveEquivalent()
    case 199: primitiveClass()
    case 200:
      success((receiverClass == OOPS.ClassMethodContextPointer) || (receiverClass == OOPS.ClassBlockContextPointer))
      if success {
        primitiveBlockCopy()
      }
    case 201, 202:
      success(receiverClass == OOPS.ClassBlockContextPointer)
      if success {
        primitiveValue()
      }
    default: primitiveFail()
    }
  }
  func primitiveResponse() -> Bool {
    if primitiveIndex == 0 {
      let flagValue = flagValueOf(newMethod)
      if flagValue == 5 {
        quickReturnSelf()
        return true
      }
      if flagValue == 6 {
        quickInstanceLoad()
        return true
      }
      return false
    } else {
      initPrimitive()
      dispatchPrimitives()
      return success
    }
  }
  func quickReturnSelf() {
    // nothing to do
  }
  func quickInstanceLoad() {
    let thisReceiver = popStack()
    let fieldIndex = fieldIndexOf(newMethod)
    push(memory.fetchPointer(fieldIndex, ofObject: thisReceiver))
  }
  func dispatchPrimitives() {
    if primitiveIndex < 60 {
      dispatchArithmeticPrimitives()
      return
    }
    if primitiveIndex < 68 {
      dispatchSubscriptAndStreamPrimitives()
      return
    }
    if primitiveIndex < 80 {
      dispatchStorageManagementPrimitives()
      return
    }
    if primitiveIndex < 90 {
      dispatchControlPrimitives()
      return
    }
    if primitiveIndex < 110 {
      dispatchInputOutputPrimitives()
      return
    }
    if primitiveIndex < 128 {
      dispatchSystemPrimitives()
      return
    }
    dispatchPrivatePrimitives()
  }
  func dispatchArithmeticPrimitives() {
    if primitiveIndex < 20 {
      dispatchIntegerPrimitives()
      return
    }
    if primitiveIndex < 40 {
      dispatchLargeIntegerPrimitives()
      return
    }
    if primitiveIndex < 60 {
      dispatchFloatPrimitives()
      return
    }
    primitiveFail()
  }
  func dispatchIntegerPrimitives() {
    switch primitiveIndex {
    case 1: primitiveAdd()
    case 2: primitiveSubtract()
    case 3: primitiveLessThan()
    case 4: primitiveGreaterThan()
    case 5: primitiveLessOrEqual()
    case 6: primitiveGreaterOrEqual()
    case 7: primitiveEqual()
    case 8: primitiveNotEqual()
    case 9: primitiveMultiply()
    case 10: primitiveDivide()
    case 11: primitiveMod()
    case 12: primitiveDiv()
    case 13: primitiveQuo()
    case 14: primitiveBitAnd()
    case 15: primitiveBitOr()
    case 16: primitiveBitXor()
    case 17: primitiveBitShift()
    case 18: primitiveMakePoint()
    default: primitiveFail()
    }
  }
  func primitiveAdd() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      integerResult = integerReceiver + integerArgument
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveSubtract() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      integerResult = integerReceiver - integerArgument
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveMultiply() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      integerResult = integerReceiver * integerArgument
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveDivide() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    success(integerArgument != 0)
    if success {
      // Would get a divide by 0 error if the arg was 0
      // so only perform if the previous check succeeded
      success(integerReceiver % integerArgument == 0)
    }
    if success {
      integerResult = integerReceiver / integerArgument
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveMod() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    success(integerArgument != 0)
    if success {
      integerResult = integerReceiver % integerArgument
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveDiv() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    success(integerArgument != 0)
    if success {
      integerResult = integerReceiver / integerArgument
      // Ensure we round to negative infinity if it was not exact
      if (integerReceiver % integerArgument != 0) && (integerResult < 0) {
        integerResult -= 1
      }
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveQuo() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    success(integerArgument != 0)
    if success {
      integerResult = integerReceiver / integerArgument
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveEqual() {
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      if integerReceiver == integerArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveNotEqual() {
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      if integerReceiver != integerArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveLessThan() {
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      if integerReceiver < integerArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveLessOrEqual() {
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      if integerReceiver <= integerArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveGreaterThan() {
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      if integerReceiver > integerArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveGreaterOrEqual() {
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      if integerReceiver >= integerArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveBitAnd() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      integerResult = integerReceiver & integerArgument
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveBitOr() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      integerResult = integerReceiver | integerArgument
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveBitXor() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      integerResult = integerReceiver ^ integerArgument
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveBitShift() {
    var integerResult: SignedWord = 0
    let integerArgument = popInteger()
    let integerReceiver = popInteger()
    if success {
      // Swift handles negative shits the same as Smalltalk
      integerResult = integerReceiver << integerArgument
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(2)
    }
  }
  func primitiveMakePoint() {
    let integerArgument = popStack()
    let integerReceiver = popStack()
    // Error in Blue Book?
    success(memory.isIntegerObject(integerReceiver))
    success(memory.isIntegerObject(integerArgument))
    if success {
      let pointResult = memory.instantiateClass(OOPS.ClassPointPointer, withPointers: ClassPointSize)
      memory.storePointer(XIndex, ofObject: pointResult, withValue: integerReceiver)
      memory.storePointer(YIndex, ofObject: pointResult, withValue: integerArgument)
      push(pointResult)
    } else {
      unPop(2)
    }
  }
  func dispatchLargeIntegerPrimitives() {
    // TODO: maybe implement these?
    primitiveFail()
  }
  func dispatchFloatPrimitives() {
    switch primitiveIndex {
    case 40: primitiveAsFloat()
    case 41: primitiveFloatAdd()
    case 42: primitiveFloatSubtract()
    case 43: primitiveFloatLessThan()
    case 44: primitiveFloatGreaterThan()
    case 45: primitiveFloatLessOrEqual()
    case 46: primitiveFloatGreaterOrEqual()
    case 47: primitiveFloatEqual()
    case 48: primitiveFloatNotEqual()
    case 49: primitiveFloatMultiply()
    case 50: primitiveFloatDivide()
    case 51: primitiveTruncated()
    case 52: primitiveFractionalPart()
    case 53: primitiveExponent()
    case 54: primitiveTimesTwoPower()
    default: primitiveFail()
    }
  }
  func primitiveAsFloat() {
    let integerReceiver = popInteger()
    if success {
      let floatValue = Float(integerReceiver)
      pushFloat(floatValue)
    } else {
      unPop(1)
    }
  }
  func primitiveFloatAdd() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      let floatResult = floatReceiver + floatArgument
      pushFloat(floatResult)
    } else {
      unPop(2)
    }
  }
  func primitiveFloatSubtract() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      let floatResult = floatReceiver - floatArgument
      pushFloat(floatResult)
    } else {
      unPop(2)
    }
  }
  func primitiveFloatLessThan() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      if floatReceiver < floatArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveFloatGreaterThan() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      if floatReceiver > floatArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveFloatLessOrEqual() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      if floatReceiver <= floatArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveFloatGreaterOrEqual() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      if floatReceiver >= floatArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveFloatEqual() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      if floatReceiver == floatArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveFloatNotEqual() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      if floatReceiver != floatArgument {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(2)
    }
  }
  func primitiveFloatMultiply() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    if success {
      let floatResult = floatReceiver * floatArgument
      pushFloat(floatResult)
    } else {
      unPop(2)
    }
  }
  func primitiveFloatDivide() {
    let floatArgument = popFloat()
    let floatReceiver = popFloat()
    success(floatArgument != 0)
    if success {
      let floatResult = floatReceiver / floatArgument
      pushFloat(floatResult)
    } else {
      unPop(2)
    }
  }
  func primitiveTruncated() {
    var integerResult: SignedWord = 0
    let floatReceiver = popFloat()
    success(floatReceiver > Float(SignedWord.min) && floatReceiver < Float(SignedWord.max))
    if success {
      integerResult = SignedWord(floatReceiver)
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(1)
    }
  }
  func primitiveFractionalPart() {
    let floatReceiver = popFloat()
    if success {
      let floatResult = floatReceiver.truncatingRemainder(dividingBy: 1)
      pushFloat(floatResult)
    } else {
      unPop(1)
    }
  }
  func primitiveExponent() {
    var integerResult: SignedWord = 0
    let floatReceiver = popFloat()
    if success {
      integerResult = SignedWord(floatReceiver.exponent)
      success(memory.isIntegerValue(integerResult))
    }
    if success {
      pushInteger(integerResult)
    } else {
      unPop(1)
    }
  }
  func primitiveTimesTwoPower() {
    let integerArgument = popInteger()
    let floatReceiver = popFloat()
    if success {
      let floatResult = floatReceiver * pow(2, Float(integerArgument))
      pushFloat(floatResult)
    } else {
      unPop(2)
    }
  }
  func dispatchSubscriptAndStreamPrimitives() {
    switch primitiveIndex {
    case 60: primitiveAt()
    case 61: primitiveAtPut()
    case 62: primitiveSize()
    case 63: primitiveStringAt()
    case 64: primitiveStringAtPut()
    case 65: primitiveNext()
    case 66: primitiveNextPut()
    case 67: primitiveAtEnd()
    default: primitiveFail()
    }
  }
  func checkIndexableBoundsOf(_ index: Int, in array: OOP) {
    let theClass = memory.fetchClassOf(array)
    success(index >= 1)
    let adjustedIndex = index + fixedFieldsOf(theClass)
    success(adjustedIndex <= lengthOf(array))
  }
  func lengthOf(_ array: OOP) -> Int {
    if isWords(memory.fetchClassOf(array)) {
      return memory.fetchWordLengthOf(array)
    } else {
      return memory.fetchByteLengthOf(array)
    }
  }
  func subscriptOf(_ array: OOP, with index: Int) -> OOP {
    let theClass = memory.fetchClassOf(array)
    if isWords(theClass) {
      if isPointers(theClass) {
        return memory.fetchPointer(index - 1, ofObject: array)
      } else {
        let value = memory.fetchWord(index - 1, ofObject: array)
        return positive32BitIntegerFor(SignedWord(value))
      }
    } else {
      let value = memory.fetchByte(index - 1, ofObject: array)
      return memory.integerObjectOf(SignedWord(value))
    }
  }
  func subscriptOf(_ array: OOP, with index: Int, storing value: OOP) {
    let theClass = memory.fetchClassOf(array)
    if isWords(theClass) {
      if isPointers(theClass) {
        memory.storePointer(index - 1, ofObject: array, withValue: value)
        return
      } else {
        success(memory.isIntegerObject(value))
        if success {
          memory.storeWord(index - 1, ofObject: array, withValue: Word(positive32BitValueOf(value)))
        }
        return
      }
    } else {
      success(memory.isIntegerObject(value))
      if success {
        let integerValue = memory.integerValueOf(value)
        memory.storeByte(index - 1, ofObject: array, withValue: UInt8(integerValue & 0xFF))
      }
    }
  }
  func primitiveAt() {
    var result: OOP = 0
    var index = Int(positive32BitValueOf(popStack()))
    let array = popStack()
    let arrayClass = memory.fetchClassOf(array)
    checkIndexableBoundsOf(index, in: array)
    if success {
      index += fixedFieldsOf(arrayClass)
      result = subscriptOf(array, with: index)
    }
    if success {
      push(result)
    } else {
      unPop(2)
    }
  }
  func primitiveAtPut() {
    let value = popStack()
    var index = Int(positive32BitValueOf(popStack()))
    let array = popStack()
    let arrayClass = memory.fetchClassOf(array)
    checkIndexableBoundsOf(index, in: array)
    if success {
      index += fixedFieldsOf(arrayClass)
      subscriptOf(array, with: index, storing: value)
    }
    if success {
      push(value)
    } else {
      unPop(3)
    }
  }
  func primitiveSize() {
    let array = popStack()
    let arrayClass = memory.fetchClassOf(array)
    let length = positive32BitIntegerFor(SignedWord(lengthOf(array) - fixedFieldsOf(arrayClass)))
    if success {
      push(length)
    } else {
      unPop(1)
    }
  }
  func primitiveStringAt() {
    var character: OOP = 0
    let index = Int(positive32BitValueOf(popStack()))
    let array = popStack()
    checkIndexableBoundsOf(index, in: array)
    if success {
      let ascii = Int(memory.integerValueOf(subscriptOf(array, with: index)))
      character = memory.fetchPointer(ascii, ofObject: OOPS.CharacterTablePointer)
    }
    if success {
      push(character)
    } else {
      unPop(2)
    }
  }
  func primitiveStringAtPut() {
    let character = popStack()
    let index = Int(positive32BitValueOf(popStack()))
    let array = popStack()
    checkIndexableBoundsOf(index, in: array)
    success(memory.fetchClassOf(character) == OOPS.ClassCharacterPointer)
    if success {
      let ascii = memory.fetchPointer(CharacterValueIndex, ofObject: character)
      subscriptOf(array, with: index, storing: ascii)
    }
    if success {
      push(character)
    } else {
      unPop(3)
    }
  }
  func primitiveNext() {
    var result: OOP = 0
    let stream = popStack()
    let array = memory.fetchPointer(StreamArrayIndex, ofObject: stream)
    let arrayClass = memory.fetchClassOf(array)
    var index = Int(fetchInteger(StreamIndexIndex, ofObject: stream))
    let limit = fetchInteger(StreamReadLimitIndex, ofObject: stream)
    success(index < limit)
    success((arrayClass == OOPS.ClassArrayPointer) || (arrayClass == OOPS.ClassStringPointer))
    checkIndexableBoundsOf(index + 1, in: array)
    if success {
      index += 1
      result = subscriptOf(array, with: index)
    }
    if success {
      storeInteger(StreamIndexIndex, ofObject: stream, withValue: SignedWord(index))
    }
    if success {
      if arrayClass == OOPS.ClassArrayPointer {
        push(result)
      } else {
        let ascii = Int(memory.integerValueOf(result))
        push(memory.fetchPointer(ascii, ofObject: OOPS.CharacterTablePointer))
      }
    } else {
      unPop(1)
    }
  }
  func primitiveNextPut() {
    let value = popStack()
    let stream = popStack()
    let array = memory.fetchPointer(StreamArrayIndex, ofObject: stream)
    let arrayClass = memory.fetchClassOf(array)
    var index = Int(fetchInteger(StreamIndexIndex, ofObject: stream))
    let limit = fetchInteger(StreamWriteLimitIndex, ofObject: stream)
    success(index < limit)
    success((arrayClass == OOPS.ClassArrayPointer) || (arrayClass == OOPS.ClassStringPointer))
    checkIndexableBoundsOf(index + 1, in: array)
    if success {
      index += 1
      if arrayClass == OOPS.ClassArrayPointer {
        subscriptOf(array, with: index, storing: value)
      } else {
        let ascii = memory.fetchPointer(CharacterValueIndex, ofObject: value)
        subscriptOf(array, with: index, storing: ascii)
      }
    }
    if success {
      storeInteger(StreamIndexIndex, ofObject: stream, withValue: SignedWord(index))
    }
    if success {
      push(value)
    } else {
      unPop(2)
    }
  }
  func primitiveAtEnd() {
    let stream = popStack()
    let array = memory.fetchPointer(StreamArrayIndex, ofObject: stream)
    let arrayClass = memory.fetchClassOf(array)
    let length = lengthOf(array)
    let index = fetchInteger(StreamIndexIndex, ofObject: stream)
    let limit = fetchInteger(StreamReadLimitIndex, ofObject: stream)
    success((arrayClass == OOPS.ClassArrayPointer) || (arrayClass == OOPS.ClassStringPointer))
    if success {
      if (index >= limit) || (index >= length) {
        push(OOPS.TruePointer)
      } else {
        push(OOPS.FalsePointer)
      }
    } else {
      unPop(1)
    }
  }
  func dispatchStorageManagementPrimitives() {
    switch primitiveIndex {
    case 68: primitiveObjectAt()
    case 69: primitiveObjectAtPut()
    case 70: primitiveNew()
    case 71: primitiveNewWithArg()
    case 72: primitiveBecome()
    case 73: primitiveInstVarAt()
    case 74: primitiveInstVarAtPut()
    case 75: primitiveAsOop()
    case 76: primitiveAsObject()
    case 77: primitiveSomeInstance()
    case 78: primitiveNextInstance()
    case 79: primitiveNewMethod()
    default: primitiveFail()
    }
  }
  func primitiveObjectAt() {
    let index = Int(popInteger())
    let thisReceiver = popStack()
    success(index > 0)
    success(index <= objectPointerCountOf(thisReceiver))
    if success {
      push(memory.fetchPointer(index - 1, ofObject: thisReceiver))
    } else {
      unPop(2)
    }
  }
  func primitiveObjectAtPut() {
    let newValue = popStack()
    let index = Int(popInteger())
    let thisReceiver = popStack()
    success(index > 0)
    success(index <= objectPointerCountOf(thisReceiver))
    if success {
      memory.storePointer(index - 1, ofObject: thisReceiver, withValue: newValue)
      push(newValue)
    } else {
      unPop(3)
    }
  }
  func primitiveNew() {
    let theClass = popStack()
    let size = fixedFieldsOf(theClass)
    success(!isIndexable(theClass))
    if success {
      if isPointers(theClass) {
        push(memory.instantiateClass(theClass, withPointers: size))
      } else {
        push(memory.instantiateClass(theClass, withWords: size))
      }
    } else {
      unPop(1)
    }
  }
  func primitiveNewWithArg() {
    var size = Int(positive32BitValueOf(popStack()))
    let theClass = popStack()
    success(isIndexable(theClass))
    if success {
      size += fixedFieldsOf(theClass)
      if isPointers(theClass) {
        push(memory.instantiateClass(theClass, withPointers: size))
      } else {
        if isWords(theClass) {
          push(memory.instantiateClass(theClass, withWords: size))
        } else {
          push(memory.instantiateClass(theClass, withBytes: size))
        }
      }
    } else {
      unPop(2)
    }
  }
  func primitiveBecome() {
    let otherPointer = popStack()
    let thisReceiver = popStack()
    success(!memory.isIntegerObject(otherPointer))
    success(!memory.isIntegerObject(thisReceiver))
    if success {
      memory.swapPointersOf(thisReceiver, and: otherPointer)
      push(thisReceiver)
    } else {
      unPop(2)
    }
  }
  func checkInstanceVariableBoundsOf(_ index: Int, in object: OOP) {
    // let theClass = memory.fetchClassOf(object)
    success(index >= 1)
    success(index <= lengthOf(object))
  }
  func primitiveInstVarAt() {
    var value: OOP = 0
    let index = Int(popInteger())
    let thisReceiver = popStack()
    checkInstanceVariableBoundsOf(index, in: thisReceiver)
    if success {
      value = subscriptOf(thisReceiver, with: index)
    }
    if success {
      push(value)
    } else {
      unPop(2)
    }
  }
  func primitiveInstVarAtPut() {
    let newValue = popStack()
    let index = Int(popInteger())
    let thisReceiver = popStack()
    checkInstanceVariableBoundsOf(index, in: thisReceiver)
    if success {
      subscriptOf(thisReceiver, with: index, storing: newValue)
    }
    if success {
      push(newValue)
    } else {
      unPop(3)
    }
  }
  func primitiveAsOop() {
    let thisReceiver = popStack()
    success(!memory.isIntegerObject(thisReceiver))
    if success {
      push(thisReceiver | 1)
    } else {
      unPop(1)
    }
  }
  func primitiveAsObject() {
    let thisReceiver = popStack()
    let newOop = thisReceiver & 0xFFFFFFFE
    success(memory.hasObject(newOop))
    if success {
      push(newOop)
    } else {
      unPop(1)
    }
  }
  func primitiveSomeInstance() {
    let theClass = popStack()
    let instance = memory.initialInstanceOf(theClass)
    if instance != OOPS.NilPointer {
      push(instance)
    } else {
      primitiveFail()
    }
  }
  func primitiveNextInstance() {
    let object = popStack()
    let instance = memory.instanceAfter(object)
    if instance != OOPS.NilPointer {
      push(instance)
    } else {
      primitiveFail()
    }
  }
  func primitiveNewMethod() {
    let header = popStack()
    let bytecodeCount = Int(popInteger())
    let theClass = popStack()
    let literalCount = literalCountOfHeader(header)
    let size = ((literalCount + 1) * BytesPerWord) + bytecodeCount
    let newMethod = memory.instantiateClass(theClass, withBytes: size)
    for i in 0 ..< literalCount {
      memory.storeWord(LiteralStart + i, ofObject: newMethod, withValue: OOPS.NilPointer)
    }
    memory.storeWord(HeaderIndex, ofObject: newMethod, withValue: header)
    push(newMethod)
  }
  func dispatchControlPrimitives() {
    switch primitiveIndex {
    case 80: primitiveBlockCopy()
    case 81: primitiveValue()
    case 82: primitiveValueWithArgs()
    case 83: primitivePerform()
    case 84: primitivePerformWithArgs()
    case 85: primitiveSignal()
    case 86: primitiveWait()
    case 87: primitiveResume()
    case 88: primitiveSuspend()
    case 89: primitiveFlushCache()
    default: primitiveFail()
    }
  }
  func primitiveBlockCopy() {
    let blockArgumentCount = popStack()
    let context = popStack()
    let methodContext = (isBlockContext(context)) ? memory.fetchPointer(HomeIndex, ofObject: context) : context
    let contextSize = memory.fetchWordLengthOf(methodContext)
    let newContext = memory.instantiateClass(OOPS.ClassBlockContextPointer, withPointers: contextSize)
    let initialIP = memory.integerObjectOf(SignedWord(instructionPointer) + 3)
    memory.storePointer(InitialIPIndex, ofObject: newContext, withValue: initialIP)
    memory.storePointer(InstructionPointerIndex, ofObject: newContext, withValue: initialIP)
    storeStackPointerValue(0, inContext: newContext)
    memory.storePointer(BlockArgumentCountIndex, ofObject: newContext, withValue: blockArgumentCount)
    memory.storePointer(HomeIndex, ofObject: newContext, withValue: methodContext)
    push(newContext)
  }
  func primitiveValue() {
    let blockContext = stackValue(argumentCount)
    let blockArgumentCount = argumentCountOfBlock(blockContext)
    success(argumentCount == blockArgumentCount)
    if success {
      transfer(argumentCount, fromIndex: stackPointer - argumentCount + 1, ofObject: activeContext,
                              toIndex: TempFrameStart, ofObject: blockContext)
      pop(argumentCount + 1)
      let initialIP = memory.fetchPointer(InitialIPIndex, ofObject: blockContext)
      memory.storePointer(InstructionPointerIndex, ofObject: blockContext, withValue: initialIP)
      storeStackPointerValue(SignedWord(argumentCount), inContext: blockContext)
      memory.storePointer(CallerIndex, ofObject: blockContext, withValue: activeContext)
      newActiveContext(blockContext)
    }
  }
  func primitiveValueWithArgs() {
    var arrayArgumentCount = 0
    let argumentArray = popStack()
    let blockContext = popStack()
    let blockArgumentCount = argumentCountOfBlock(blockContext)
    let arrayClass = memory.fetchClassOf(argumentArray)
    success(arrayClass == OOPS.ClassArrayPointer)
    if success {
      arrayArgumentCount = memory.fetchWordLengthOf(argumentArray)
      success(arrayArgumentCount == blockArgumentCount)
    }
    if success {
      transfer(arrayArgumentCount, fromIndex: 0, ofObject: argumentArray,
                                   toIndex: TempFrameStart, ofObject: blockContext)
      let initialIP = memory.fetchPointer(InitialIPIndex, ofObject: blockContext)
      memory.storePointer(InstructionPointerIndex, ofObject: blockContext, withValue: initialIP)
      storeStackPointerValue(SignedWord(arrayArgumentCount), inContext: blockContext)
      memory.storePointer(CallerIndex, ofObject: blockContext, withValue: activeContext)
      newActiveContext(blockContext)
    } else {
      unPop(2)
    }
  }
  func primitivePerform() {
    let performSelector = messageSelector
    messageSelector = stackValue(argumentCount - 1)
    let newReceiver = stackValue(argumentCount)
    lookupMethodInClass(memory.fetchClassOf(newReceiver))
    success(argumentCountOf(newMethod) == (argumentCount - 1))
    if success {
      let selectorIndex = stackPointer - argumentCount + 1
      transfer(argumentCount - 1, fromIndex: selectorIndex + 1, ofObject: activeContext,
                                  toIndex: selectorIndex, ofObject: activeContext)
      pop(1)
      argumentCount = argumentCount - 1
      executeNewMethod()
    } else {
      messageSelector = performSelector
    }
  }
  func primitivePerformWithArgs() {
    let argumentArray = popStack()
    let arraySize = memory.fetchWordLengthOf(argumentArray)
    let arrayClass = memory.fetchClassOf(argumentArray)
    success((stackPointer + arraySize) < (memory.fetchWordLengthOf(activeContext)))
    success(arrayClass == OOPS.ClassArrayPointer)
    if success {
      let performSelector = messageSelector
      messageSelector = popStack()
      let thisReceiver = stackTop()
      argumentCount = arraySize
      var index = 1
      while index <= argumentCount {
        push(memory.fetchPointer(index - 1, ofObject: argumentArray))
        index = index + 1
      }
      lookupMethodInClass(memory.fetchClassOf(thisReceiver))
      success(argumentCountOf(newMethod) == argumentCount)
      if success {
        executeNewMethod()
      } else {
        unPop(argumentCount)
        push(messageSelector)
        push(argumentArray)
        argumentCount = 2
        messageSelector = performSelector
      }
    } else {
      unPop(1)
    }
  }
  func asynchronousSignal(_ aSemaphore: OOP) {
    semaphoreIndex += 1
    semaphoreList[semaphoreIndex] = aSemaphore
  }
  func synchronousSignal(_ aSemaphore: OOP) {
    if isEmptyList(aSemaphore) {
      let excessSignals = fetchInteger(ExcessSignalsIndex, ofObject: aSemaphore)
      storeInteger(ExcessSignalsIndex, ofObject: aSemaphore, withValue: excessSignals + 1)
    } else {
      resume(removeFirstLinkOfList(aSemaphore))
    }
  }
  func transferTo(_ aProcess: OOP) {
    newProcessWaiting = true
    newProcess = aProcess
  }
  func activeProcess() -> OOP {
    if newProcessWaiting {
      return newProcess
    } else {
      return memory.fetchPointer(ActiveProcessIndex, ofObject: schedulerPointer())
    }
  }
  func schedulerPointer() -> OOP {
    return memory.fetchPointer(ValueIndex, ofObject: OOPS.SchedulerAssociationPointer)
  }
  func firstContext() -> OOP {
    newProcessWaiting = false
    return memory.fetchPointer(SuspendedContextIndex, ofObject: activeProcess())
  }
  func removeFirstLinkOfList(_ aLinkedList: OOP) -> OOP {
    let firstLink = memory.fetchPointer(FirstLinkIndex, ofObject: aLinkedList)
    let lastLink = memory.fetchPointer(LastLinkIndex, ofObject: aLinkedList)
    if lastLink == firstLink {
      memory.storePointer(FirstLinkIndex, ofObject: aLinkedList, withValue: OOPS.NilPointer)
      memory.storePointer(LastLinkIndex, ofObject: aLinkedList, withValue: OOPS.NilPointer)
    } else {
      let nextLink = memory.fetchPointer(NextLinkIndex, ofObject: firstLink)
      memory.storePointer(FirstLinkIndex, ofObject: aLinkedList, withValue: nextLink)
    }
    memory.storePointer(NextLinkIndex, ofObject: firstLink, withValue: OOPS.NilPointer)
    return firstLink
  }
  func addLastLink(_ aLink: OOP, toList aLinkedList: OOP) {
    if isEmptyList(aLinkedList) {
      memory.storePointer(FirstLinkIndex, ofObject: aLinkedList, withValue: aLink)
    } else {
      let lastLink = memory.fetchPointer(LastLinkIndex, ofObject: aLinkedList)
      memory.storePointer(NextLinkIndex, ofObject: lastLink, withValue: aLink)
    }
    memory.storePointer(LastLinkIndex, ofObject: aLinkedList, withValue: aLink)
    memory.storePointer(MyListIndex, ofObject: aLink, withValue: aLinkedList)
  }
  func isEmptyList(_ aLinkedList: OOP) -> Bool {
    return memory.fetchPointer(FirstLinkIndex, ofObject: aLinkedList) == OOPS.NilPointer
  }
  func wakeHighestPriority() -> OOP {
    var processList: OOP = OOPS.NilPointer
    let processLists = memory.fetchPointer(ProcessListsIndex, ofObject: schedulerPointer())
    var priority = memory.fetchWordLengthOf(processLists)
    while (processList = memory.fetchPointer(priority - 1, ofObject: processLists), isEmptyList(processList)).1 {
      priority -= 1
    }
    return removeFirstLinkOfList(processList)
  }
  func sleep(_ aProcess: OOP) {
    let priority = Int(fetchInteger(PriorityIndex, ofObject: aProcess))
    let processLists = memory.fetchPointer(ProcessListsIndex, ofObject: schedulerPointer())
    let processList = memory.fetchPointer(priority - 1, ofObject: processLists)
    addLastLink(aProcess, toList: processList)
  }
  func suspendActive() {
    transferTo(wakeHighestPriority())
  }
  func resume(_ aProcess: OOP) {
    let thisActiveProcess = activeProcess()
    let activePriority = fetchInteger(PriorityIndex, ofObject: thisActiveProcess)
    let newPriority = fetchInteger(PriorityIndex, ofObject: aProcess)
    if newPriority > activePriority {
      sleep(thisActiveProcess)
      transferTo(aProcess)
    } else {
      sleep(aProcess)
    }
  }
  func primitiveSignal() {
    synchronousSignal(stackTop())
  }
  func primitiveWait() {
    let thisReceiver = stackTop()
    let excessSignals = fetchInteger(ExcessSignalsIndex, ofObject: thisReceiver)
    if excessSignals > 0 {
      storeInteger(ExcessSignalsIndex, ofObject: thisReceiver, withValue: excessSignals - 1)
    } else {
      addLastLink(activeProcess(), toList: thisReceiver)
      suspendActive()
    }
  }
  func primitiveResume() {
    resume(stackTop())
  }
  func primitiveSuspend() {
    success(stackTop() == activeProcess())
    if success {
      popStack()
      push(OOPS.NilPointer)
      suspendActive()
    }
  }
  func primitiveFlushCache() {
    initializeMethodCache()
  }
  func dispatchInputOutputPrimitives() {
    switch primitiveIndex {
    case 90: primitiveMousePoint()
    case 91: primitiveCursorLocPut()
    case 92: primitiveCursorLink()
    case 93: primitiveInputSemaphore()
    case 94: primitiveSampleInterval()
    case 95: primitiveInputWord()
    case 96: primitiveCopyBits()
    case 97: primitiveSnapshot()
    case 98: primitiveTimeWordsInto()
    case 99: primitiveTickWordsInto()
    case 100: primitiveSignalAtTick()
    case 101: primitiveBeCursor()
    case 102: primitiveBeDisplay()
    case 103: primitiveScanCharacters()
    case 104: primitiveDrawLoop()
    case 105: primitiveStringReplace()
    default: primitiveFail()
    }
  }
  func primitiveMousePoint() {
  }
  func primitiveCursorLocPut() {
  }
  func primitiveCursorLink() {
  }
  func primitiveInputSemaphore() {
  }
  func primitiveSampleInterval() {
  }
  func primitiveInputWord() {
  }
  func primitiveCopyBits() {
  }
  func primitiveSnapshot() {
  }
  func primitiveTimeWordsInto() {
  }
  func primitiveTickWordsInto() {
  }
  func primitiveSignalAtTick() {
  }
  func primitiveBeCursor() {
  }
  func primitiveBeDisplay() {
  }
  func primitiveScanCharacters() {
  }
  func primitiveDrawLoop() {
  }
  func primitiveStringReplace() {
  }
  func dispatchSystemPrimitives() {
    switch primitiveIndex {
    case 110: primitiveEquivalent()
    case 111: primitiveClass()
    case 112: primitiveCoreLeft()
    case 113: primitiveQuit()
    case 114: primitiveExitToDebugger()
    case 115: primitiveOopsLeft()
    case 116: primitiveSignalAtOopsLeftWordsLeft()
    default: primitiveFail()
    }
  }
  func primitiveEquivalent() {
    let otherObject = popStack()
    let thisObject = popStack()
    if thisObject == otherObject {
      push(OOPS.TruePointer)
    } else {
      push(OOPS.FalsePointer)
    }
  }
  func primitiveClass() {
    let instance = popStack()
    push(memory.fetchClassOf(instance))
  }
  func primitiveCoreLeft() {
    pop(1)
    // TODO: make this related to available RAM
    push(positive32BitIntegerFor(SignedWord.max))
  }
  func primitiveQuit() {
    exit(0)
  }
  func primitiveExitToDebugger() {
    exit(0)
  }
  func primitiveOopsLeft() {
    pop(1)
    // TODO: make this related to available RAM
    push(positive32BitIntegerFor(SignedWord.max))
  }
  func primitiveSignalAtOopsLeftWordsLeft() {
    let numWords = positive32BitValueOf(popStack())
    let numOops = positive32BitValueOf(popStack())
    let semaphore = popStack()
    success((memory.fetchClassOf(semaphore) == OOPS.ClassSemaphorePointer) || (semaphore == OOPS.NilPointer))
    if success {
      // TODO: save the semaphore and limits and monitor space available
      // signalling the semaphore when space is low
      print("Watchdog semaphore for memory below \(numOops) oops, \(numWords) words")
    } else {
      unPop(3)
    }
  }

  func dispatchPrivatePrimitives() {
  }
}
