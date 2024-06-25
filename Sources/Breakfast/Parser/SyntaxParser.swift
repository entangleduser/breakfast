public struct SyntaxParser<Base: Collection>: ~Copyable
 where Base.SubSequence: SubSequential,
 Base.SubSequence.PreSequence == Base {
 public typealias Fragment = Base.SubSequence
 public typealias Fragments = [Base.SubSequence]
 public typealias Token = ComponentData<Base>
 public typealias Tokens = [Token]
 public var base: Base
 public let lexer: Lexer
 /// The position within the base sequence
 public lazy var index: Base.Index = base.startIndex
 /// A lazily loaded partioned base sequence
 public lazy var parts: Fragments = lexer(base)
 /// The position within the partitioned sequence
 public lazy var cursor: Int = parts.startIndex
 public lazy var tokens: Tokens = .empty

 @_transparent
 public var trivial: Fragments { lexer.trivial }

 public init(_ base: Base, with lexer: Lexer) {
  self.base = base
  self.lexer = lexer
 }
}

public extension SyntaxParser {
 struct Lexer {
  public var trivial: [Base.SubSequence] = .empty
  public let splitWhere: (Base.Element) -> Bool
  public func callAsFunction(_ input: Base) -> [Base.SubSequence] {
   input.partition(whereSeparator: splitWhere)
  }
 }
}

public extension SyntaxParser.Lexer {
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

public extension SyntaxProtocol {
 typealias Parser<Base> = SyntaxParser<Base>
  where Base: Collection, Base.SubSequence: SubSequential,
  Base.SubSequence.PreSequence == Base
}
