/// A protocol for filtering a base sequence broken down into subseqence parts
public protocol SyntaxProtocol<Base> {
 associatedtype Base: ParseableSequence
 typealias BaseParser = SyntaxParser<Base>
 typealias Syntax = SyntaxProtocol<Base>
 typealias Token = ComponentData<Base>
 typealias Tokens = [Token]
 typealias Fragment = Base.SubSequence
 typealias Fragments = [Base.SubSequence]
 typealias Syntactic = SyntaxBuilder<Base>
 typealias Components = [any SyntaxProtocol<Base>]

 /// A function that parses fragements from a parser and returns a hint
 /// indicating a match.
 ///
 /// - returns: A boolean value indicating a match was found.
 @discardableResult
 func parse(with parser: inout BaseParser) throws -> Bool
 @Syntactic
 var components: Components { get }
}

public extension SyntaxProtocol {
 @_transparent
 @_disfavoredOverload
 var components: Components { .empty }
 @_transparent
 @_disfavoredOverload
 @discardableResult
 func parse(with parser: inout BaseParser) throws -> Bool {
  removeTrivia(with: &parser)
  for component in components {
   if try component.parse(with: &parser) {
    removeTrivia(with: &parser)
    continue
   } else {
    return false
   }
  }
  return true
 }
}

public typealias AnySyntax<A> = any SyntaxProtocol<A> where A: Collection
public protocol ParseableSequence: Collection where Self.SubSequence: Equatable,
 Self.SubSequence: SubSequential,
 Self.SubSequence.PreSequence == Self {}
/// A throwing assertions rather than terminating, for testing purposes
@usableFromInline
func assert(
 _ condition: Bool,
 _ message: String? = nil,
 file: String = #file,
 line: Int = #line,
 column: Int = #column
) throws {
 if let message {
  try condition.throwing(
   reason:
   "\(file.split(separator: "/").last!):\(line.description):\(column.description) \(message)"
  )
 } else {
  try condition.throwing()
 }
}

/// A throwing unwrap, for testing purposes
@discardableResult
@usableFromInline
func unwrap<A>(
 _ optional: A?,
 _ message: String? = nil,
 file: String = #file,
 line: Int = #line,
 column: Int = #column
) throws -> A {
 if let message {
  try optional.throwing(
   reason:
   "\(file.split(separator: "/").last!):\(line.description):\(column.description) \(message)"
  )
 } else {
  try optional.throwing()
 }
}

public extension SyntaxProtocol {
 // TODO: move to final parser implementation
 @discardableResult
 func removeTrivia(with parser: inout Parser<Base>) -> Bool {
  // FIXME: cannot generalize parts here
  if let items = parser.parts.removeTrivia(for: parser.trivial) {
   for trivia in items {
    let first = trivia.first.unsafelyUnwrapped.first.unsafelyUnwrapped
    parser.tokens.append(.trivial(first, count: trivia.count))
    parser.cursor += trivia.count
   }
   return true
  }
  return false
 }
}

/// A rule to use the `apply` function to a collection of rules
public struct ApplySyntax<Base: ParseableSequence>: SyntaxProtocol {
 public var component: any Syntax
 public init(_ component: any Syntax) { self.component = component }
 @_transparent
 public func parse(with parser: inout Parser<Base>)
  throws -> Bool {
  try component.parse(with: &parser)
 }
}

/// A rule to break from one **unique** subsequence to another and apply rules
/// to the contents
/// Note: Every rule witin the content closure will be applied until the end is
/// reached
public struct BreakSyntax<Base: ParseableSequence>: SyntaxProtocol {
 public let lhs: Fragment
 public let rhs: Fragment
 @Syntactic
 @usableFromInline
 var header: (Int) -> Self.Components
 @Syntactic
 @usableFromInline
 var content: (Int) -> Self.Components
 @_transparent
 public func parse(with parser: inout Parser<Base>)
  throws -> Bool {
  removeTrivia(with: &parser)

  let breakSequence =
   try unwrap(
    parser.parts.break(from: lhs, to: rhs),
    "expected closing bracket"
   )

  let range = ..<breakSequence.startIndex
  // var rebase = parser.parts[range].map { $0 }

  let headerComponents = header(breakSequence.startIndex)
  let contentComponents = content(breakSequence.endIndex)

  for component in headerComponents {
   removeTrivia(with: &parser)
   try component.parse(with: &parser)
   removeTrivia(with: &parser)
  }

//  parser.parts.removeSubrange(range)
  parser.cursor = range.upperBound + 1
  // parser.cursor += 1
  // parser.parts.removeFirst()
  let lhs: Token = .parameter(
   .bracket.start, with: .sequence(parser.parts[parser.cursor])
  )

  parser.tokens.append(lhs)

  while parser.cursor < breakSequence.endIndex {
   for component in contentComponents {
    if
     try component.parse(with: &parser) {
     break
    }
   }
   // remove trivia, skip ahead if there's none
   if removeTrivia(with: &parser) {
    parser.cursor = parser.parts.startIndex
   } else {
    parser.cursor += 1
   }
  }

  if parser.parts.notEmpty {
   parser.cursor += 1
   let rhs: Token = .parameter(
    .bracket.end, with: .sequence(parser.parts[parser.cursor])
   )
   parser.tokens.append(rhs)
  }
  return true
 }

 public init(
  from lhs: Token.SubSequence, to rhs: Token.SubSequence,
  @Syntactic header: @escaping (Int) -> Self.Components,
  @Syntactic content: @escaping (Int) -> Self.Components
 ) {
  self.lhs = lhs
  self.rhs = rhs
  self.header = header
  self.content = content
 }
}

public extension SyntaxProtocol {
 typealias Break = BreakSyntax<Base>
}

public struct PerformSyntax<Base: ParseableSequence>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 public typealias Action = (_ parser: inout Parser<Base>) throws -> Bool
 public let action: Action

 public init(action: @escaping Action) {
  self.action = action
 }

 public func parse(with parser: inout Parser<Base>) throws -> Bool {
  try action(&parser)
 }
}

public extension SyntaxProtocol {
 typealias Perform = PerformSyntax<Base>
}

public struct WordSyntax<Base: ParseableSequence>: SyntaxProtocol {
 public init() {}
 public func parse(with parser: inout Parser<Base>) throws -> Bool {
  let index = parser.cursor
  guard index < parser.parts.endIndex else {
   return false
  }

  parser.cursor += 1
  parser.tokens.append(.sequence(parser.parts[index]))
  return true
 }
}

public extension SyntaxProtocol {
 typealias Word = WordSyntax<Base>
}

public struct RepeatSyntax<Base: ParseableSequence>: SyntaxProtocol {
 @Syntactic
 var contents: () -> Self.Components

 public func parse(with parser: inout Parser<Base>) throws -> Bool {
  let components = contents()
  while parser.cursor < parser.parts.endIndex {
   for component in components {
    // break when a rule returns true
    // to restart from the top
    // and continue when false
    // to find a suitable syntax
    if try component.parse(with: &parser) {
     break
    } else {
     continue
    }
   }
  }
  return parser.cursor < parser.parts.endIndex
 }

 public init(@Syntactic _ contents: @escaping () -> Self.Components) {
  self.contents = contents
 }
}

public extension SyntaxProtocol {
 typealias Repeat = RepeatSyntax<Base>
}

public struct RemainingSyntax<Base: ParseableSequence>: SyntaxProtocol {
 public init(component: AnyComponent = .unknown) {
  self.component = component
 }

 public var component: AnyComponent = .unknown
 public func parse(with parser: inout Parser<Base>) throws -> Bool {
  if parser.cursor < parser.parts.endIndex {
   parser.tokens.append(
    .parameter(component, with: .slice(parser.parts[parser.cursor...]))
   )
  }
  return false
 }
}

public extension SyntaxProtocol {
 typealias Remaining = RemainingSyntax<Base>
}

public struct OffsetSyntax<Base: ParseableSequence>: SyntaxProtocol {
 var amount: Int = 1

 public init(_ amount: Int = 1) {
  self.amount = amount
 }

 public func parse(with parser: inout BaseParser) throws -> Bool {
  parser.cursor += amount
  return true
 }
}

extension SyntaxProtocol {
 typealias Offset = OffsetSyntax<Base>
}
