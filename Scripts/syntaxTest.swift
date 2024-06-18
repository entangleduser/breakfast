#!/usr/bin/env -S swift-shell --testable
@testable import Breakfast // ..
import Benchmarks // @git/acrlc/benchmarks
import Command // @git/acrlc/command
import Tests // @git/acrlc/acrylic

struct ExplicitTypeSyntax: SyntaxProtocol {
 let component: TypeComponent
 let limitWhere: ([Substring]) throws -> Int?

 init(with component: TypeComponent, limit: Int? = nil) {
  self.component = component
  limitWhere = { _ in limit }
 }

 init(
  with component: TypeComponent,
  limitWhere condition: @escaping ([Substring]) throws -> Int?
 ) {
  self.component = component
  limitWhere = condition
 }

 @discardableResult
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  guard parts.first == ":" else {
   return true
  }

  // let limit = try limitWhere(parts) ?? parts.endIndex

  let token: Token =
   .delimiter(from: .identifier(component.id), to: component, with: ":")
  tokens.append(token)
  parts.removeFirst()

  removeTrivia(&tokens, for: trivial, with: &parts)

  // try assert(cursor < limit, "expected type")

  let type = try unwrap(parts.first, "missing type'")

  try assert(
   type.allSatisfy { $0.isAlphaNumeric || $0 == "_" },
   "invalid type \(type)"
  )

  parts.removeFirst()

  let typeToken: Token = .parameter(component, with: .sequence(type))
  tokens.append(typeToken)

  return true
 }
}

public struct AssignmentSyntax: SyntaxProtocol {
 /// Applies the first rule that returns true
 @SyntaxBuilder<String>
 public var contents: () -> [AnySyntax<String>]
 @discardableResult
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  let part = try unwrap(parts.first, "expected expression")
  guard part == "=" else {
   return false
  }
  do {
   parts.removeFirst()

   let token: Token =
    .delimiter(from: .identifier.property, to: .symbol.assignment, with: "=")
   tokens.append(token)

   removeTrivia(&tokens, for: trivial, with: &parts)

   for rule in contents() {
    if
     try rule.erased.apply(
      &tokens,
      with: &parts,
      at: &cursor,
      trivial: trivial
     ) {
     removeTrivia(&tokens, for: trivial, with: &parts)
     return true
    }
   }
   return false
  } catch {
   throw error
  }
 }
}

struct WordSyntax: SyntaxProtocol {
 @discardableResult
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  guard parts.notEmpty else {
   return false
  }
  let token: Token = .sequence(parts.removeFirst())
  tokens.append(token)
  return true
 }
}

struct SomeSyntax: SyntaxProtocol {
 typealias Components = [AnySyntax<String>]

 func declaration(
  _ tokens: inout [Token],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring],
  keyword: Token.SubSequence
 ) {
  switch keyword {
  case "var": break
  case "struct": break
  default: break
  }
 }

 @Syntactic
 var propertyDeclaration: Components {
  ExplicitTypeSyntax(
   with: .type.property,
   limitWhere: { $0.firstIndex(of: "=") }
  )
  AssignmentSyntax {
   StringLiteralSyntax()
   WordSyntax()
  }
 }

 @Syntactic
 var variableDeclaration: Components {
  ExplicitTypeSyntax(
   with: .type.property,
   limitWhere: { $0.firstIndex(of: "=") }
  )
  AssignmentSyntax {
   StringLiteralSyntax()
   WordSyntax()
  }
  Break(
   from: "{", to: "}", header: { limit in
    ExplicitTypeSyntax(with: .type.property, limit: limit)
   }, content: { _ in
    StringLiteralSyntax()
   }
  )
 }

 @Syntactic
 var typeContent: Components {
  StringLiteralSyntax()
 }

 @Syntactic
 func typeDeclaration(_ keyword: Substring) -> Components {
  Break(
   from: "{", to: "}", header: { limit in
    ExplicitTypeSyntax(with: .type(keyword), limit: limit)
    // ?? Assert(\.cursor, { $0 < limit })
   }, content: { _ in
    typeContent
   }
  )
 }

 @Syntactic
 func declarationContent(_ keyword: Substring) -> Components {
  switch keyword {
  case "struct", "class":
   typeDeclaration(keyword)
  case "let":
   propertyDeclaration
  case "var":
   propertyDeclaration
  default:
   declarationSyntax
  }
 }

 var declarationSyntax: DeclarationSyntax {
  DeclarationSyntax(
   keywords: [
    "struct", "class", "actor", "let", "var", "func", "typealias"
   ],
   parse: declaration,
   contents: declarationContent
  )
 }

 var components: Components {
  PreprocessorSyntax()
  Repeat { declarationSyntax }
 }
}

// MARK: - SyntaxTests
@main
struct TestSyntax: StaticTests {
 typealias Base = String
 typealias Token = ComponentData<Base>

 var tests: some Testable {
  let testString =
   """
   #!usr/bin/env swift shell
   class HelloWorld: Equatable {}
   let str = "Some message"
   var name: String = "Swift"
   var interpolated: Substring = "Hello \\(name)"
   """

  TestNaiveSyntax()
  Benchmark {
   Measure("Parse SomeSyntax", iterations: 10) {
    let syntax = SomeSyntax()

    var parser = BaseParser<String>(testString, with: .backtickEscapedCode)
    var parts = parser.parts
    var cursor = parser.cursor
    var tokens: [Token] = .empty

    try syntax.apply(
     &tokens, with: &parts, at: &cursor, trivial: parser.lexer.trivial
    )

    let colored: [String] = tokens.map { token in
     let string = token.string
     let component = token.component

     switch component.description {
     case "word.declaration":
      return "\(string, color: .magenta, style: .bold)"
     case "identifier.struct", "identifier.class":
      return "\(string, color: .cyan, style: .bold)"
     case "type.struct", "type.class", "type.property":
      return "\(string, color: .cyan)"
     case "string.literal", "string.static":
      return "\(string, color: .yellow, style: .bold)"
     case "string.interpolated":
      var str = string
      let prefix: Substring = str.dropFirst(2)
      let suffix: Character = str.removeLast()
      return "\(prefix)\(str, style: .dim)\(suffix)"
     case "preprocessor.argument":
      return "\(string, color: .magenta, style: .dim)"
     case "preprocessor.processor":
      return "\(string, color: .magenta)"
     case "preprocessor.hashbang":
      return "\(string, color: .magenta, style: .bold)"
     default: return string
     }
    }

    print(colored.joined())
   }
  }
 }
}

extension String.Index: ExpressibleAsStart {
 public static let start = unsafeBitCast(0, to: Self.self)
}

extension Substring: ExpressibleAsEmpty {
 public static var empty: Self = .init()
 public var isEmpty: Bool { count == .zero }
}

/// The position used to diagnose errors located in a source file
public struct LinearPosition: ExpressibleAsStart {
 public var line: Int = .zero
 public var column: Int = .zero
 public static let start = Self()
}

public extension LinearPosition {
 init(of index: String.Index, in string: String) {
  self.init()
  guard index > .start else {
   return
  }
  // search the first until reaching a newline or the end of the sequence
  if
   let firstIndex = string.firstIndex(of: .newline),
   firstIndex != string.endIndex {
   if firstIndex >= index {
    let substring = string[.start ..< firstIndex]
    self.init(line: .zero, column: index.utf16Offset(in: substring))
   } else {
    var currentIndex: Int = 0
    // the last total offset where a newline occurs
    var lastOffset = firstIndex
    for offset in string.indices[firstIndex ..< string.endIndex] {
     let character = string[offset]
     if offset == index {
      let last = lastOffset.utf16Offset(in: string)
      let distance = offset.utf16Offset(in: string) - 1
      self.init(line: currentIndex, column: distance - last)
     } else if character == .newline {
      currentIndex += 1
      lastOffset = offset
     }
    }
   }
  } else if index < string.endIndex {
   self.init(line: .zero, column: index.utf16Offset(in: string))
  }
 }
}

extension LinearPosition: CustomStringConvertible {
 public var description: String { "\(line):\(column)" }
}

public extension StringProtocol {
 func startPosition(in string: String) -> LinearPosition {
  LinearPosition(of: startIndex, in: string)
 }

 func endPosition(in string: String) -> LinearPosition {
  LinearPosition(of: endIndex, in: string)
 }
}

struct TestNaiveSyntax: Tests, SyntaxProtocol {
 typealias Base = String
 typealias Token = ComponentData<String>
 let sep: (Character) -> Bool = {
  ($0.isPunctuation && $0 != "`") || $0.isSymbol || $0.isWhitespace || $0
   .isNewline
 }

 let trivial: [Substring] = [.space, .newline]

 @Modular
 var componentTests: some Testable {
  Identity("comment.mark") == CommentComponent.mark.description
  Identity("string.literal") == StringComponent.literal.description
  Identity("string.interpolated") == StringComponent.interpolated.description
  Identity("string.escaped") == StringComponent.escaped.description
  Identity("string.static") == StringComponent.static.description
  Identity("type.class") == TypeComponent.class.description
  Identity("type.struct") == TypeComponent.struct.description
  Identity("type.generic") == TypeComponent.generic.description
  Identity("type.property") == TypeComponent.property.description
  Identity("type.function") == TypeComponent.function.description
 }

 var tests: some Testable {
  componentTests
  parseKeywordVariable

  Perform("Parse Preprocessor") {
   var tokens: [Token] = .empty
   let rule = PreprocessorSyntax()
   let str = "#!usr/bin/env python interpreter.py"
   var base = str.partition(whereSeparator: sep)
   var cursor = base.startIndex

   try rule.apply(&tokens, with: &base, at: &cursor, trivial: trivial)

   let description = tokens.map(\.debugDescription).joined(separator: .newline)
   try assert(
    """
    "#!", as: preprocessor.hashbang
    "usr/bin/env", as: preprocessor.processor
    " ", count: 1
    "python", as: preprocessor.argument
    " ", count: 1
    "interpreter.py", as: preprocessor.argument
    """
     == description
   )
  }

  Perform("Parse String") {
   var tokens: [Token] = .empty
   let rule = StringLiteralSyntax()
   let str =
    """
    "\\(header): Some message"
    """
   var base = str.partition(whereSeparator: sep)
   var cursor = base.startIndex

   try rule.apply(&tokens, with: &base, at: &cursor, trivial: trivial)

   try assert(tokens.count == 3)
   try assert(
    tokens[0]
     .debugDescription == #"ArraySlice(["\""]), as: string.static"#
   )
   try assert(
    #"ArraySlice(["\\", "(", "header", ")"]), as: string.interpolated"#
     == tokens[1].debugDescription
   )
   try assert(
    #"""
    ArraySlice([":", " ", "Some", " ", "message", "\""]), as: string.static
    """#
     == tokens[2].debugDescription
   )
  }
 }
}

extension TestNaiveSyntax {
 @Modular
 var parseKeywordVariable: some Testable {
  Perform("Parse Keyword Variable") { () -> String in
   let str = "var string: String { \"\\(one) string \\(two)\\(three) \" }"
   var _tokens: [Token] = .empty

   // find the start of a sequence based on a symbol or keyword
   let keywords: Set<Token.SubSequence> = ["let", "var", "func"]

   var base = str.partition(whereSeparator: sep)
   var cursor = base.startIndex
   var sub: ArraySlice<Substring> { base[cursor...] }

   func removeTrivia() -> Bool {
    if let items = base.removeTrivia(for: trivial) {
     for trivia in items {
      _tokens.append(.trivial(trivia.first!.first!, count: trivia.count))
     }
     cursor = base.startIndex
     return true
    }
    return false
   }

//   removeTrivia()
   // look for the first index through keywords, before parsing
//   cursor = try unwrap(base.firstIndex(where: { keywords.contains($0) }))
//
//   let keyword = base[cursor]
//   let token: Token = .parameter(.word.declaration, with: .sequence(keyword))
//
//   _tokens.append(token)
//
//   cursor =
//    try unwrap(
//     base.index(cursor, offsetBy: 1, limitedBy: base.endIndex),
//     "expected identifier for variable declaration"
//    )
//
//   // parts of the keyword sequence that resolve into individual components
//   var parts: [Token] = .empty
//
//   let keybreaks: [Token.SubSequence] = ["=", "{"]
//   let keybreak: Int = try unwrap({
//    var index: Int?
//    for keyword in keybreaks {
//     guard let key = sub.firstIndex(of: keyword) else {
//      continue
//     }
//     if let previous = index {
//      if previous < key {
//       index = key
//      }
//     }
//     else {
//      index = key
//     }
//    }
//    return index
//   }(), "expected = or { to match variable declaration")
//
//   let keySeparator = sub[keybreak]
//   base.removeFirst()
//
//   var key: ArraySlice<Substring> { sub[..<keybreak] }
//
//   removeTrivia()
//
//   // MARK: - Keyword
//   let identifier =
//    try unwrap(key.first, "missing identifier for '\(keyword)'")
//
//   try assert(base.removeFirst() == "string")
//
//   let idToken: Token = .parameter(
//    .identifier.property,
//    with: .sequence(identifier)
//   )
//   parts.append(idToken)
//
//   let computed = keySeparator == "{"
//   removeTrivia()
//
//   let hasType = key.first == ":"
//
//   try assert(
//    computed ? hasType : true,
//    "expected type for '\(keyword) \(identifier)'"
//   )
//   let bracket = computed ? sub.break(from: "{", to: "}") : nil
//
//   if hasType {
//    let token: Token =
//     .delimiter(from: .identifier.property, to: .type.property, with: ":")
//    _tokens.append(token)
//    base.removeFirst()
//    removeTrivia()
//
//    try assert(cursor < keybreak, "expected type")
//
//    let type = try unwrap(key.first, "missing type for '\(key) \(identifier)'")
//
//    // MARK: - Type
//    try assert(
//     !(type.hasPrefix("_") || type.hasSuffix("_")),
//     "type cannot begin or end with an underscore"
//    )
//    try assert(
//     type.allSatisfy { $0.isAlphaNumeric || $0 == "_" },
//     "invalid type \(type)"
//    )
//
//    try assert(base.removeFirst() == "String")
//
//    let typeToken: Token = .parameter(.type.property, with: .sequence(type))
//    parts.append(typeToken)
//   }
//
//   // modify cursor for the keyword break, regardless of what's thrown
//   cursor = keybreak
//
//   if parts.notEmpty {
//    _tokens.append(contentsOf: parts)
//   }
//
//   removeTrivia()
//
//   var deferredTokens: [Token] = .empty
//
//   if computed {
//    let bracket = try unwrap(bracket, "expected closing bracket")
//    let lhs: Token = .parameter(
//     .bracket.start, with: .element(bracket.first!.first!)
//    )
//
//    cursor += 1
//
//    _tokens.append(lhs)
//
//    base.removeFirst()
//    let rhs: Token = .parameter(
//     .bracket.end, with: .element(bracket.last!.first!)
//    )
//
//    deferredTokens.append(rhs)
//   }
//
//   // find the decipherable contents of the closure
//   // which are determined from the context determined by the keyword
//   // cursor = content.startIndex
//
//   let controlwords: Set<Substring> = ["return"]
//   let symbols: Set<Substring> = ["="]
//   var words: [Token] = .empty
//
//   func appendParts(_ tokens: inout [Token]) {
//    if tokens.notEmpty {
//     _tokens.append(contentsOf: tokens)
//     tokens = .empty
//    }
//   }
//
//   removeTrivia()
//
//   while cursor < sub.endIndex {
//    let part = sub[cursor]
//
//    if symbols.contains(part) {
//     if part.count == 1 {
//      switch part {
//      case "=":
//       let sequence = base.trimPrefix(of: part)!
//       if sequence.count == 1 {
//        let token: Token = .parameter(
//         .symbol.assignment, with: .element(part.first!)
//        )
//        parts.append(token)
//       } else {
//        cursor = sequence.endIndex
//       }
//      default: break
//      }
//     }
//    } else if controlwords.contains(part) {
//     let token: Token = .parameter(.word.control, with: .sequence(part))
//     parts.append(token)
//    } else if part.hasPrefix("\"") {
//     appendParts(&words)
//
//     // MARK: String content
//     let stringBreak =
//      try unwrap(sub.breakEven(from: "\"", to: "\""), "unterminated string")
//
//     var parts: [Token] = .empty
//
//     // find escaped characters
//     let validEscapes: Set<Token.SubSequence> = ["n", "s", "b", "t"]
//     if let escapeIndex = stringBreak.firstIndex(of: "\\") {
//      let `static` = stringBreak[stringBreak.startIndex ..< escapeIndex]
//      let token: Token = .parameter(.string.static, with: .slice(`static`))
//      parts.append(token)
//
//      let stringEndIndex = stringBreak.endIndex
//
//      func escape(at index: Int) throws {
//       let nextIndex =
//        try unwrap(
//         stringBreak.index(index, offsetBy: 1, limitedBy: stringEndIndex),
//         "expected escape sequence"
//        )
//       let escape = stringBreak[nextIndex]
//       if escape == "(" {
//        let part = stringBreak[index...]
//        // split into simple parts (or recurse)
//        let match =
//         try unwrap(
//          part.break(from: "(", to: ")"),
//          "unterminated string interpolation"
//         )
//
//        let endIndex = match.endIndex
//
//        let slice = stringBreak[index ..< endIndex]
//
//        let token: Token = .parameter(.string.interpolated, with: .slice(slice))
//        parts.append(token)
//
//        cursor = endIndex
//       } else {
//        try assert(
//         validEscapes.contains(escape),
//         "invalid escape sequence ending with\(escape)"
//        )
//
//        let slice = stringBreak[escapeIndex ..< nextIndex]
//        let token: Token = .parameter(.string.escaped, with: .slice(slice))
//
//        parts.append(token)
//        cursor = stringBreak.index(after: nextIndex)
//       }
//      }
//
//      try escape(at: escapeIndex)
//
//      while let escapeIndex = stringBreak[cursor...].firstIndex(of: "\\") {
//       let `static` = stringBreak[cursor ..< escapeIndex]
//       if `static`.count > 0 {
//        let token: Token = .parameter(.string.static, with: .slice(`static`))
//        parts.append(token)
//       }
//       try escape(at: escapeIndex)
//      }
//
//      if cursor < stringEndIndex {
//       let `static` = stringBreak[cursor...]
//       let token: Token = .parameter(.string.static, with: .slice(`static`))
//       parts.append(token)
//       cursor = stringBreak.endIndex
//      }
//     } else {
//      let token: Token = .parameter(.string.literal, with: .slice(stringBreak))
//      parts.append(token)
//      base.removeSubrange(base.startIndex ..< cursor)
//      cursor = stringBreak.endIndex
//      continue
//     }
//     appendParts(&parts)
//     base.removeSubrange(base.startIndex ..< cursor)
//    } else {
//     let token: Token = .sequence(part)
//     words.append(token)
//    }
//
//    if let items = base.removeTrivia(for: trivial) {
//     let count = items.reduce(0) { $0 + $1.count }
//     for trivia in items {
//      _tokens.append(.trivial(trivia.first!.first!, count: trivia.count))
//     }
//     if count == base.count {
//      appendParts(&deferredTokens)
//     }
//     cursor = base.endIndex
//    } else {
//     cursor += 1
//     if cursor == base.endIndex {
//      appendParts(&deferredTokens)
//      break
//     }
//    }
//   }
//
//   appendParts(&words)
//   removeTrivia()
//
//   cursor = sub.startIndex

   return _tokens.map(\.debugDescription).joined(separator: .newline)
  }
 }
}

func unwrap<A>(_ value: A?, _ message: String? = nil) throws -> A {
 if let message {
  try value.throwing(reason: message)
 } else {
  try value.throwing()
 }
}
