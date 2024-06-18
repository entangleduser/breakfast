/// A syntax for swift with some static utilities to render tokens using
/// `SwiftSyntax`
public struct SwiftCodeSyntax: SyntaxProtocol {
 public typealias Base = String
 public typealias Components = [AnySyntax<String>]
 public init() {}

 public var components: Components {
  PreprocessorSyntax()
  Repeat {
   declarationSyntax
  }
  Remaining()
 }

 public var declarationSyntax: DeclarationSyntax {
  DeclarationSyntax(
   keywords: [
    "struct", "class", "actor", "let", "var", "func", "typealias"
   ],
   parse: declaration,
   contents: declarationContent
  )
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

 func declaration(
  _ tokens: inout [Token],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring],
  keyword: Token.SubSequence
 ) {
  // TODO: actually parse
  switch keyword {
  case "var": break
  case "struct": break
  default: break
  }
 }
}

// MARK: Components

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
 @SyntaxBuilder<Base>
 public var contents: () -> [AnySyntax<Base>]
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

#if canImport(SwiftSyntax) && canImport(SwiftParser)
import SwiftParser
import SwiftSyntax
extension SwiftCodeSyntax {
 static func renderTokensWithSwiftSyntax(from input: String) -> [Token] {
  var tokens: [Token] = .empty
  if applyWithSwiftSyntax(from: input, &tokens) {
   return tokens
  }
  return .empty
 }

 public static func applyWithSwiftSyntax(
  from input: String,
  _ tokens: inout [ComponentData<String>]
 ) -> Bool {
  guard input.notEmpty else {
   return false
  }

  let data = SwiftParser.Parser.parse(source: input)
  let syntax = SwiftSyntax.Syntax(data)

  var next = syntax.firstToken(viewMode: .sourceAccurate)

  guard let first = next else {
   return false
  }

  var previous: TokenSyntax?

  func range(_ token: TokenSyntax) -> Range<String.Index> {
   let range = token.trimmedByteRange
   let position = range.offset
   let offset = range.endOffset
   return String.Index(utf16Offset: position, in: input) ..<
    String.Index(utf16Offset: offset, in: input)
  }

  func setTrivia(
   _ piece: TriviaPiece,
   length: Int,
   position: TriviaPosition,
   byteOffset: Int,
   with token: TokenSyntax
  ) {
   let isTrailing = position == .trailing
   let sourcePosition = (
    isTrailing
     ? token.trimmedByteRange.endOffset
     : token.totalByteRange.offset
   ) +
    byteOffset

   let offset = sourcePosition + length
   let range =
    String.Index(utf16Offset: sourcePosition, in: input) ..<
    String.Index(utf16Offset: offset, in: input)

   var str = input[range]
   switch piece {
   case .newlines(let count):
    tokens.append(.trivial(.newline, count: count))
   case .spaces(let count):
    tokens.append(.trivial(.space, count: count))
   case .tabs(let count):
    tokens.append(.trivial(.tab, count: count))
   case .lineComment:
    tokens.append(
     .parameter(
      .comment.open,
      with: .sequence(str[..<str.index(str.startIndex, offsetBy: 2)])
     )
    )

    str.removeFirst(2)

    let component: CommentComponent = if
     str.hasPrefix(" TODO: ") || str.hasPrefix(" todo: ") {
     // TODO: separate these components from the line
     .comment.todo
    } else
    if str.hasPrefix(" MARK: ") {
     .comment.mark
    } else
    if str.hasPrefix(" FIXME: ") || str.hasPrefix(" fixme: ") {
     .comment.fixme
    } else {
     .comment.line
    }

    tokens.append(
     .parameter(component, with: .sequence(str))
    )
   case .blockComment:
    tokens.append(
     .parameter(.comment.block, with: .sequence(str))
    )
   case .docLineComment:
    tokens.append(
     .parameter(.documentation.line, with: .sequence(str))
    )
   case .docBlockComment:
    tokens.append(
     .parameter(.documentation.block, with: .sequence(str))
    )
   default: break
   }
  }
  var startingText = input[range(first)]

  if startingText.hasPrefix("#!") {
   let exclamationIndex = startingText.firstIndex(of: "!").unsafelyUnwrapped
   let token: Token =
    .parameter(
     .preprocessor.hashbang,
     with: .sequence(startingText[...exclamationIndex])
    )

   tokens.append(token)

   startingText.removeFirst(2)

   var splits = startingText.split(
    separator: .space,
    omittingEmptySubsequences: true
   )

   tokens.append(
    .parameter(.preprocessor.processor, with: .sequence(splits.removeFirst()))
   )

   while !splits.isEmpty {
    // TODO: account for trivia
    tokens.append(
     .parameter(.preprocessor.argument, with: .sequence(splits.removeFirst()))
    )
   }

   next = first.nextToken(viewMode: .sourceAccurate)
  }
  while let token = next {
   let kind = token.tokenKind
   guard kind != .endOfFile else {
    break
   }

   let txt = token.text
   lazy var str = input[range(token)]
   let peek = token.nextToken(viewMode: .sourceAccurate)

   defer {
    next = peek

    var offset: Int = .zero
    for piece in token.trailingTrivia.pieces {
     let length = piece.sourceLength.utf8Length
     setTrivia(
      piece,
      length: length,
      position: .trailing,
      byteOffset: offset,
      with: token
     )
     offset += length
    }

    previous = token
   }

   var offset: Int = .zero
   for piece in token.leadingTrivia.pieces {
    let length = piece.sourceLength.utf8Length
    setTrivia(
     piece,
     length: length,
     position: .leading,
     byteOffset: offset,
     with: token
    )
    offset += length
   }

   switch kind {
   case .keyword(let type):
    tokens.append(
     .parameter(
      .string.literal,
      with: .sequence(str)
     )
    )
    switch type {
    case .func:
     tokens.append(
      .parameter(
       .word.declaration(.function),
       with: .sequence(str)
      )
     )
    default:
     tokens.append(
      .parameter(
       .word.declaration(.custom(txt)),
       with: .sequence(input[range(token)])
      )
     )
    }
   case .stringSegment:
    tokens.append(
     .parameter(
      .string.literal,
      with: .sequence(str)
     )
    )
   case .integerLiteral:
    tokens.append(
     .parameter(
      .integer.literal,
      with: .sequence(str)
     )
    )
   case .floatLiteral:
    tokens.append(
     .parameter(
      .float.literal,
      with: .sequence(str)
     )
    )
   case .identifier(let id):
    func checkForKeyPathOrIdentifier(_ previousKind: TokenKind? = nil) {
     // TODO: differentiate from declarative functions with parameters
     // and string interpolation contents which should be considered as
     // variables
     // and keypath identifieres
     if let peek {
      let nextKind = peek.tokenKind
      if nextKind == .colon || previousKind == .leftParen {
       tokens.append(
        .parameter(
         .identifier.custom("parameter"),
         with: .sequence(str)
        )
       )
      } else if previousKind == .period {
       tokens.append(
        .parameter(
         .identifier.path,
         with: .sequence(str)
        )
       )
      } else if nextKind == .leftParen {
       tokens.append(
        .parameter(
         .identifier.imperative,
         with: .sequence(str)
        )
       )
      } else {
       tokens.append(
        .parameter(
         .identifier.unknown,
         with: .sequence(str)
        )
       )
      }
     } else {
      tokens.append(
       .parameter(
        .identifier.unknown,
        with: .sequence(str)
       )
      )
     }
    }
    if let previous {
     let previousKind = previous.tokenKind
     let isCapitalized = id.first!.isUppercase

     let previousKeyword: Keyword? = switch previousKind {
     case .keyword(let keyword): keyword
     default: nil
     }

     let isTypeClassification =
      previousKeyword == .class ||
      previousKeyword == .struct ||
      previousKeyword == .extension ||
      previousKeyword == .protocol

     let isImperativeClassification =
      // note: imperative classifications can only be proven by subsequent
      // scans
      // identifiying the root structure
      isCapitalized || id.hasPrefix(.underscore) && (
       previousKind == .leftAngle ||
        previousKind == .colon ||
        previousKind == .comma ||
        previousKeyword == .some ||
        peek?.tokenKind == .leftParen ||
        peek?.tokenKind == .leftAngle
      )
     if isTypeClassification {
      let component: AnyComponent = switch previousKeyword.unsafelyUnwrapped {
      case .class: .type.class
      case .struct: .type.struct
      case .extension: .type.extension
      case .protocol: .type.protocol
      default: fatalError()
      }
      tokens.append(
       .parameter(component, with: .sequence(str))
      )
     } else if isImperativeClassification {
      tokens.append(
       .parameter(.type.imperative, with: .sequence(str))
      )
     } else if
      previousKeyword == .let || previousKeyword == .var ||
      previousKeyword == .func {
      let component: AnyComponent = switch previousKeyword.unsafelyUnwrapped {
      case .let, .var: .identifier.property
      case .func: .identifier.function
      default: fatalError()
      }
      tokens.append(
       .parameter(component, with: .sequence(str))
      )
     } else {
      checkForKeyPathOrIdentifier(previousKind)
     }
    } else {
     checkForKeyPathOrIdentifier()
    }
   default:
    if kind == .stringQuote {
     if let peek {
      switch peek.tokenKind {
      case .stringSegment:
       tokens.append(
        .parameter(.string.open, with: .sequence(str))
       )
       continue
      default: break
      }
     }
     if let kind = previous?.tokenKind {
      switch kind {
      case .stringSegment:
       tokens.append(
        .parameter(.string.close, with: .sequence(str))
       )
       continue
      default: break
      }
     }
    }

    switch previous?.tokenKind {
    case .some(let kind):
     switch kind {
     case .keyword(let type):
      switch type {
      case .func:
       debugPrint(type)
       tokens.append(
        .parameter(
         .identifier.function,
         with: .sequence(str)
        )
       )
       continue
      default: break
      }
     default: break
     }
    default: break
    }
    tokens.append(
     .parameter(
      .unknown,
      with: .sequence(str)
     )
    )
   }
  }
  return true
 }
}
#endif
