public struct BaseParser<Base: Collection>
 where Base.SubSequence: SubSequential,
 Base.SubSequence.PreSequence == Base {
 public var base: Base
 public let lexer: Lexer
 /// The position within the base sequence
 public lazy var index: Base.Index = base.startIndex
 /// A lazily loaded partioned base sequence
 public lazy var parts: [Base.SubSequence] = lexer(base)
 /// The position within the partitioned sequence
 public lazy var cursor: Int = parts.startIndex

 public init(_ base: Base, with lexer: Lexer) {
  self.base = base
  self.lexer = lexer
 }
}

public extension BaseParser {
 struct Lexer {
  public var trivial: [Base.SubSequence] = .empty
  public let splitWhere: (Base.Element) -> Bool
  public func callAsFunction(_ input: Base) -> [Base.SubSequence] {
   input.partition(whereSeparator: splitWhere)
  }
 }
}

public extension BaseParser.Lexer {
 init(
  _ trivia: [Base.SubSequence] = .empty,
  splitWhere: @escaping (Base.Element) -> Bool
 ) {
  self.init(trivial: trivia, splitWhere: splitWhere)
 }

 static func withTrivia(
  _ trivia: [Base.SubSequence], splitWhere: @escaping (Base.Element) -> Bool
 ) -> Self {
  Self(trivial: trivia, splitWhere: splitWhere)
 }
}
