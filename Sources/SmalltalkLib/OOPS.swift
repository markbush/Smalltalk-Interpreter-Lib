enum OOPS {
  // SmallIntegers
  static let MinusOnePointer: OOP = OOP.max
  static let ZeroPointer: OOP = 1
  static let OnePointer: OOP = 3
  static let TwoPointer: OOP = 5

  // UndefinedObject and Booleans
  static let NilPointer: OOP = 2
  static let FalsePointer: OOP = 4
  static let TruePointer: OOP = 6

  // Root
  static let SchedulerAssociationPointer: OOP = 8
  static let SmalltalkPointer: OOP = 25286 // SystemDictionary

  // Classes
  static let ClassSmallInteger: OOP = 12
  static let ClassStringPointer: OOP = 14
  static let ClassArrayPointer: OOP = 16
  static let ClassMethodContextPointer: OOP = 22
  static let ClassBlockContextPointer: OOP = 24
  static let ClassPointPointer: OOP = 26
  static let ClassLargePositiveIntegerPointer: OOP = 28
  static let ClassMessagePointer: OOP = 32
  static let ClassCharacterPointer: OOP = 40
  static let ClassCompiledMethod: OOP = 34
  static let ClassSymbolPointer: OOP = 56

  static let ClassFloatPointer: OOP = 20

  static let ClassSemaphorePointer: OOP = 38
  static let ClassDisplayScreenPointer: OOP = 834
  static let ClassUndefinedObject: OOP = 25728

  // Selectors
  static let DoesNotUnderstandSelector: OOP = 42
  static let CannotReturnSelector: OOP = 44
  static let MustBeBooleanSelector: OOP = 52

  // Tables
  static let SpecialSelectorsPointer: OOP = 48
  static let CharacterTablePointer: OOP = 50
}
