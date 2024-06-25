public struct PreprocessorSyntax: StringSyntax {
 public init() {}
 public func parse(with parser: inout BaseParser)throws -> Bool {
  guard parser.cursor < parser.parts.endIndex else {
   return false
  }
  let prefix = parser.parts[..<2].joined()

  if prefix == "#!" {
   parser.cursor += 2
   // parser.parts.removeFirst(2)

   let breakIndex =
    parser.parts.firstIndex(where: { $0 == .newline }) ?? parser.parts.endIndex

   var splits =
    parser.parts[..<breakIndex].joined().partition { $0 == .space }

   parser.tokens.append(
    .component(
     .preprocessor.hashbang, with: .sequence(Substring(prefix))
    )
   )

   let processor = splits.removeFirst()

   parser.tokens.append(
    .component(.preprocessor.processor, with: .sequence(processor))
   )

   while splits.notEmpty {
    removeTrivia(with: &parser)
    if splits.notEmpty {
     let sequence = splits.removeFirst()
     parser.tokens.append(
      .component(.preprocessor.argument, with: .sequence(sequence))
     )
    }
   }

   removeTrivia(with: &parser)

   parser.cursor = breakIndex
   //parser.parts.removeSubrange(..<breakIndex)
   return true
  }
  return true
 }
}

/// A rule to apply to declarations based on `keywords`
public struct DeclarationSyntax: StringSyntax {
 public let keywords: Set<Substring>
 public typealias Action = PerformSyntax<Base>.Action
 /// The function performed after adding the identifier component
 public let action: Action

 @Syntactic
 var contents: (Substring) -> [AnySyntax<Base>]

 public init(
  keywords: Set<Substring>,
  action: @escaping Action,
  @Syntactic contents: @escaping (Substring) -> [AnySyntax<Base>]
 ) {
  self.keywords = keywords
  self.action = action
  self.contents = contents
 }

 public func parse(with parser: inout Parser<Base>)throws -> Bool {
  guard let part = parser.parts.first else {
   return false
  }

  if keywords.contains(part) {
   parser.parts.removeFirst()

   let key: Token = .parameter(
    .word.declaration(.custom(String(part))),
    with: .sequence(part)
   )
   parser.tokens.append(key)

   removeTrivia(with: &parser)

   let identifier = try unwrap(
    parser.parts.first,
    "missing identifier for '\(part)'"
   )

   try Breakfast.assert(
    identifier.count > 1
     ? !(identifier.hasPrefix("_") || identifier.hasSuffix("_"))
     : true, // apply other rules
    "identifier cannot begin or end with an underscore"
   )

   parser.cursor += 1
   //parser.parts.removeFirst()

   let token: Token = .parameter(.identifier(part), with: .sequence(identifier))
   parser.tokens.append(token)

   if try action(&parser) {
    for component in contents(part) {
     removeTrivia(with: &parser)
     try component.parse(with: &parser)
     removeTrivia(with: &parser)
    }
   } else {
    // throw?
    return false
   }
  }
  return true
 }
}

/// A rule to apply to a string at the current cursor
public struct StringLiteralSyntax: StringSyntax {
 public init() {}
 public func parse(with parser: inout BaseParser)throws -> Bool {
  guard let part = parser.parts.first else {
   return false
  }
  // TODO: create syntax loop that reads the first part
  if part.hasPrefix("\"") {
//   let sep: (Substring)throws -> Bool = {
//    guard $0.count == 1 else { return false }
//    let char = $0.first!
//    return char.isPunctuation || char.isWhitespace || char.isNewline
//   }

   let stringBreak =
    try unwrap(
     parser.parts.breakEven(from: "\"", to: "\""),
     "unterminated string"
    )

   var queue: [Token] = .empty

   // print("Found string break \(stringBreak)")

   // find escaped characters
   let validEscapes: Set<Token.SubSequence> = ["n", "s", "b", "t"]

   if let escapeIndex = stringBreak.firstIndex(of: "\\") {
    // print("Recursing 'string' content", parts[cursor...])

    let `static` = stringBreak[stringBreak.startIndex ..< escapeIndex]
    let token: Token = .parameter(.string.static, with: .slice(`static`))
    queue.append(token)

    let stringEndIndex = stringBreak.endIndex

    func escape(at index: Int) throws {
     let nextIndex =
      try unwrap(
       stringBreak.index(index, offsetBy: 1, limitedBy: stringEndIndex),
       "expected escape sequence"
      )

     let nextCharacter = stringBreak.element(after: index)
     if nextCharacter == "(" {
      // let escape = nextCharacter.unsafelyUnwrapped.first!
      let part = stringBreak[index...]
      // split into simple parts (or recurse)
      let match =
       try unwrap(
        part.break(from: "(", to: ")"),
        "unterminated string interpolation"
       )

      let endIndex = match.endIndex

      let slice = stringBreak[index ..< endIndex]

      let token: Token = .parameter(.string.interpolated, with: .slice(slice))
      queue.append(token)

      parser.cursor = endIndex
     } else {
      if let escape = nextCharacter {
       try Breakfast.assert(
        validEscapes.contains(escape),
        "invalid escape sequence ending with\(escape)"
       )
      }

      let slice = stringBreak[escapeIndex ..< nextIndex]
      let token: Token = .parameter(.string.escaped, with: .slice(slice))

      parser.cursor += 1
      //parser.parts.removeFirst()

      queue.append(token)
      parser.cursor = stringBreak.index(after: nextIndex)
     }
    }

    try escape(at: escapeIndex)

    while
     parser.cursor < stringBreak.endIndex,
     let escapeIndex = stringBreak[parser.cursor...].firstIndex(of: "\\") {
     let `static` = stringBreak[parser.cursor ..< escapeIndex]
     if `static`.count > 0 {
      let token: Token = .parameter(.string.static, with: .slice(`static`))
      queue.append(token)
     }
     try escape(at: escapeIndex)
    }

    if parser.cursor < stringEndIndex {
     let `static` = stringBreak[parser.cursor...]
     let token: Token = .parameter(.string.static, with: .slice(`static`))
     queue.append(token)
     parser.cursor = stringBreak.endIndex
    }
   } else {
    let token: Token = .parameter(.string.literal, with: .slice(stringBreak))
    parser.tokens.append(token)
    parser.parts
     .removeSubrange(parser.parts.startIndex ..< stringBreak.endIndex)
    return true
   }
   parser.tokens.append(contentsOf: queue)
   let endCursor = parser.cursor < parser.parts.endIndex
   ? parser.cursor
    : parser.parts.endIndex
//   parser.parts.removeSubrange(parser.parts.startIndex ..< endCursor)
   parser.cursor = endCursor + 1
//   parser.cursor += 1
   return true
  }
  return false
 }
}
