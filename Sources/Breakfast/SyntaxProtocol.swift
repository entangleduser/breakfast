public typealias AnySyntax<A> = any SyntaxProtocol<A> where A: Collection

/// A protocol for filtering a base sequence broken down into subseqence parts
public protocol SyntaxProtocol<Base> where Base.SubSequence: Equatable {
 associatedtype Base: Collection
 typealias Syntactic = SyntaxBuilder<Base>
 @Syntactic
 var components: [AnySyntax<Base>] { get }
 @discardableResult
 /// Applies a rule using a mutable context to move the cursor and collect
 /// tokens from syntax parts
 func apply(
  _ tokens: inout [ComponentData<Base>],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool
 // TODO: skip when throwing and attempt to resolve when finished
 // there will need to be optional context for errors using a more feature
 // complete protocol
}

public extension SyntaxProtocol {
 typealias Syntax = SyntaxProtocol<Base>
 typealias Token = ComponentData<Base>
 typealias SubSequence = Base.SubSequence
 typealias Components = [AnySyntax<Base>]

 @_disfavoredOverload
 var components: Components { [] }
 @_disfavoredOverload
 @discardableResult
 func apply(
  _ tokens: inout [Token],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  removeTrivia(&tokens, for: trivial, with: &parts)
  for rule in components {
   if
    try rule.erased.apply(
     &tokens,
     with: &parts,
     at: &cursor,
     trivial: trivial
    ) {
    removeTrivia(&tokens, for: trivial, with: &parts)
    continue
   } else {
    return false
   }
  }
  return true
 }

 /// A throwing assertions rather than terminating, for testing purposes
 @inlinable
 func assert(
  _ condition: Bool,
  _ message: String? = nil,
  file: String = #file,
  line: Int = #line,
  column: Int = #column
 ) throws {
  if let message {
   try condition.throwing(
    reason: "\(file.split(separator: "/").last!):\(line.description):\(column.description) \(message)"
   )
  } else {
   try condition.throwing()
  }
 }

 /// A throwing unwrap, for testing purposes
 @discardableResult
 @inlinable
 func unwrap<A>(
  _ optional: A?,
  _ message: String? = nil,
  file: String = #file,
  line: Int = #line,
  column: Int = #column
 ) throws -> A {
  if let message {
   try optional.throwing(
    reason: "\(file.split(separator: "/").last!):\(line.description):\(column.description) \(message)"
   )
  } else {
   try optional.throwing()
  }
 }
}

@resultBuilder
public enum SyntaxBuilder<Base: Collection> where Base.SubSequence: Equatable {
 public typealias Component = AnySyntax<Base>
 public typealias Components = [Component]
 public static func buildBlock(_ components: Components) -> Components {
  components
 }

 public static func buildBlock(_ components: Component...) -> Components {
  components
 }

 @SyntaxBuilder<Base>
 public static func buildEither(first: Components)
  -> Components {
  first
 }

 @SyntaxBuilder<Base>
 public static func buildEither(second: Components?)
  -> Components {
  second == nil ? .empty : second.unsafelyUnwrapped
 }

 public static func buildOptional(_ optional: Component?) -> Components {
  optional == nil ? .empty : [optional.unsafelyUnwrapped]
 }

 @SyntaxBuilder<Base>
 public static func buildLimitedAvailability(_ component: Component)
  -> Components {
  component
 }
}

public extension SyntaxProtocol {
 // TODO: move to final parser implementation
 @discardableResult
 func removeTrivia(
  _ tokens: inout [Token],
  for trivial: [Base.SubSequence],
  with parts: inout [Base.SubSequence]
 ) -> Bool {
  // FIXME: cannot generalize parts here
  if let items = parts.removeTrivia(for: trivial) {
   for trivia in items {
    let first = trivia.first.unsafelyUnwrapped.first.unsafelyUnwrapped
    tokens.append(.trivial(first, count: trivia.count))
   }
   return true
  }
  return false
 }
}

public struct ErasedSyntax<Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 public var value: AnySyntax<Base>
 public let rule: (AnySyntax<Base>) -> (
  inout [Token],
  inout [SubSequence],
  inout Int,
  [SubSequence]
 ) throws -> Bool

 @discardableResult
 public func apply(
  _ tokens: inout [ComponentData<Base>],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  try rule(value)(&tokens, &parts, &cursor, trivial)
 }

 public init<A: SyntaxProtocol>(_ value: A) where A.Base == Base {
  self.value = value
  rule = { ($0 as! A).apply }
 }
}

public extension SyntaxProtocol {
 @inlinable
 var erased: ErasedSyntax<Base> { ErasedSyntax(self) }
}

/// A rule to use the `apply` function to a collection of rules
public struct ApplySyntax<A: SyntaxProtocol>: SyntaxProtocol {
 public typealias Base = A.Base
 public var rule: A
 public init(_ rule: A) { self.rule = rule }
 public func apply(
  _ tokens: inout [Token],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  try rule.apply(&tokens, with: &parts, at: &cursor, trivial: trivial)
 }
}

/// A rule to break from one **unique** subsequence to another and apply rules
/// to the contents
/// Note: Every rule witin the content closure will be applied until the end is
/// reached
public struct BreakSyntax<Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 public typealias Token = ComponentData<Base>
 public let lhs: SubSequence
 public let rhs: SubSequence
 @SyntaxBuilder<Base>
 var header: (Int) -> Components
 @SyntaxBuilder<Base>
 var content: (Int) -> Components
 public func apply(
  _ tokens: inout [Token],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  removeTrivia(&tokens, for: trivial, with: &parts)

  let breakSequence =
   try unwrap(parts.break(from: lhs, to: rhs), "expected closing bracket")

  let range = ..<breakSequence.startIndex
  var rebase = parts[range].map { $0 }

  let headerRules = header(breakSequence.startIndex)
  let contentRules = content(breakSequence.endIndex)

  for rule in headerRules {
   removeTrivia(&tokens, for: trivial, with: &rebase)
   try rule.erased.apply(&tokens, with: &rebase, at: &cursor, trivial: trivial)
   removeTrivia(&tokens, for: trivial, with: &rebase)
  }

  parts.removeSubrange(range)

  let lhs: Token = .parameter(
   .bracket.start, with: .sequence(parts.removeFirst())
  )

  tokens.append(lhs)

  while cursor < breakSequence.endIndex {
   for rule in contentRules {
    if
     try rule.erased.apply(
      &tokens,
      with: &parts,
      at: &cursor,
      trivial: trivial
     ) {
     break
    }
   }
   // remove trivia, skip ahead if there's none
   if removeTrivia(&tokens, for: trivial, with: &parts) {
    cursor = parts.startIndex
   } else {
    cursor += 1
   }
  }

  if parts.notEmpty {
   let rhs: Token = .parameter(
    .bracket.end, with: .sequence(parts.removeFirst())
   )
   tokens.append(rhs)
  }
  return true
 }

 public init(
  from lhs: Token.SubSequence, to rhs: Token.SubSequence,
  @SyntaxBuilder<Base> header: @escaping (Int) -> Components,
  @SyntaxBuilder<Base> content: @escaping (Int) -> Components
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

public struct GroupSyntax<ID: Hashable, Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 public var id: ID?
 @SyntaxBuilder<Base>
 var contents: () -> Components

 public var components: [AnySyntax<Base>] { contents() }

 public init(
  _ id: ID? = nil, @SyntaxBuilder<Base> _ contents: @escaping () -> Components
 ) {
  self.id = id
  self.contents = contents
 }
}

public extension SyntaxProtocol {
 typealias Group<ID> = GroupSyntax<ID, Base> where ID: Hashable
}

public struct EmptySyntax<Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 public init() {}
}

public extension SyntaxProtocol {
 typealias Empty = EmptySyntax<Base>
}

public struct PerformSyntax<Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 public let action: (
  inout [Token],
  inout [SubSequence],
  inout Int,
  [SubSequence]
 ) throws -> Bool

 public init(
  action: @escaping (
   inout [PerformSyntax<Base>.Token],
   inout [PerformSyntax<Base>.SubSequence], inout Int,
   [PerformSyntax<Base>.SubSequence]
  ) throws -> Bool
 ) {
  self.action = action
 }

 public func apply(
  _ tokens: inout [ComponentData<Base>],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  try action(&tokens, &parts, &cursor, trivial)
 }
}

public extension SyntaxProtocol {
 typealias Perform = PerformSyntax<Base>
}

public struct RepeatSyntax<Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 @SyntaxBuilder<Base>
 var contents: () -> Components

 public func apply(
  _ tokens: inout [ComponentData<Base>],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  let rules = contents()
  while cursor < parts.endIndex, parts.notEmpty {
   for rule in rules {
    // break when a rule returns true
    // to restart from the top
    // and continue when false
    // to find a suitable syntax
    if
     try rule.erased.apply(
      &tokens,
      with: &parts,
      at: &cursor,
      trivial: trivial
     ) {
     break
    } else {
     continue
    }
   }
  }
  return cursor < parts.endIndex
 }

 public init(@SyntaxBuilder<Base> _ contents: @escaping () -> Components) {
  self.contents = contents
 }
}

public extension SyntaxProtocol {
 typealias Repeat = RepeatSyntax<Base>
}

public struct RemainingSyntax<Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 public init(component: AnyComponent = .unknown) {
  self.component = component
 }

 public var component: AnyComponent = .unknown
 public func apply(
  _ tokens: inout [ComponentData<Base>],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  if cursor < parts.endIndex {
   tokens.append(
    .parameter(component, with: .slice(parts[cursor...]))
   )
  }
  return false
 }
}

public extension SyntaxProtocol {
 typealias Remaining = RemainingSyntax<Base>
}
