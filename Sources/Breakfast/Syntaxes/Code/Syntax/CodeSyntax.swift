public struct PreprocessorSyntax: SyntaxProtocol {
 public init() {}
 @discardableResult
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  guard parts.count > 1 else {
   return false
  }
  let prefix = parts[..<2].joined()

  if prefix == "#!" {
   parts.removeFirst(2)

   let breakIndex =
    parts.firstIndex(where: { $0 == .newline }) ?? parts.endIndex

   var splits =
    parts[..<breakIndex].joined().partition { $0 == .space }

   tokens.append(
    .component(
     .preprocessor.hashbang, with: .sequence(Substring(prefix))
    )
   )

   let processor = splits.removeFirst()

   tokens.append(
    .component(.preprocessor.processor, with: .sequence(processor))
   )

   while splits.notEmpty {
    removeTrivia(&tokens, for: trivial, with: &splits)
    if splits.notEmpty {
     let sequence = splits.removeFirst()
     tokens.append(
      .component(.preprocessor.argument, with: .sequence(sequence))
     )
    }
   }

   removeTrivia(&tokens, for: trivial, with: &splits)

   parts.removeSubrange(..<breakIndex)
   return true
  }
  return true
 }
}

/// A rule to apply to declarations based on `keywords`
public struct DeclarationSyntax: SyntaxProtocol {
 public let keywords: Set<Substring>
 /// The function performed after adding the identifier component
 public let parse: (
  inout [Token],
  inout [Substring],
  inout Int,
  [Substring],
  Substring
 ) throws -> ()

 @SyntaxBuilder<Base>
 var contents: (Substring) -> Components

 public init(
  keywords: Set<Substring>,
  parse: @escaping (
   inout [DeclarationSyntax.Token],
   inout [Substring],
   inout Int,
   [Substring],
   Substring
  ) throws -> (),
  @Syntactic contents: @escaping (Substring) -> DeclarationSyntax.Components
 ) {
  self.keywords = keywords
  self.parse = parse
  self.contents = contents
 }

 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  guard let part = parts.first else {
   return false
  }
  
  if keywords.contains(part) {
   parts.removeFirst()

   let key: Token = .parameter(
    .word.declaration(.custom(String(part))),
    with: .sequence(part)
   )
   tokens.append(key)

   removeTrivia(&tokens, for: trivial, with: &parts)

   let identifier = try unwrap(parts.first, "missing identifier for '\(part)'")

   try assert(
    identifier.count > 1
     ? !(identifier.hasPrefix("_") || identifier.hasSuffix("_"))
     : true, // apply other rules
    "identifier cannot begin or end with an underscore"
   )

   parts.removeFirst()

   let token: Token = .parameter(.identifier(part), with: .sequence(identifier))
   tokens.append(token)

   try parse(&tokens, &parts, &cursor, trivial, part)

   for rule in contents(part) {
    removeTrivia(&tokens, for: trivial, with: &parts)
    try rule.erased.apply(&tokens, with: &parts, at: &cursor, trivial: trivial)
    removeTrivia(&tokens, for: trivial, with: &parts)
   }
  } else {
   // throw?
   return false
  }
  return true
 }
}

/// A rule to apply to a string at the current cursor
public struct StringLiteralSyntax: SyntaxProtocol {
 public init() {}
 @discardableResult
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  guard let part = parts.first else {
   return false
  }
  // TODO: create syntax loop that reads the first part
  if part.hasPrefix("\"") {
//   let sep: (Substring) -> Bool = {
//    guard $0.count == 1 else { return false }
//    let char = $0.first!
//    return char.isPunctuation || char.isWhitespace || char.isNewline
//   }

   let stringBreak =
    try unwrap(parts.breakEven(from: "\"", to: "\""), "unterminated string")

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
      //let escape = nextCharacter.unsafelyUnwrapped.first!
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

      cursor = endIndex
     } else {
      if let escape = nextCharacter {
       try assert(
        validEscapes.contains(escape),
        "invalid escape sequence ending with\(escape)"
       )
      }

      let slice = stringBreak[escapeIndex ..< nextIndex]
      let token: Token = .parameter(.string.escaped, with: .slice(slice))

      parts.removeFirst()

      queue.append(token)
      cursor = stringBreak.index(after: nextIndex)
     }
    }

    try escape(at: escapeIndex)

    while
     cursor < stringBreak.endIndex,
     let escapeIndex = stringBreak[cursor...].firstIndex(of: "\\") {
     let `static` = stringBreak[cursor ..< escapeIndex]
     if `static`.count > 0 {
      let token: Token = .parameter(.string.static, with: .slice(`static`))
      queue.append(token)
     }
     try escape(at: escapeIndex)
    }

    if cursor < stringEndIndex {
     let `static` = stringBreak[cursor...]
     let token: Token = .parameter(.string.static, with: .slice(`static`))
     queue.append(token)
     cursor = stringBreak.endIndex
    }
   } else {
    let token: Token = .parameter(.string.literal, with: .slice(stringBreak))
    tokens.append(token)
    parts.removeSubrange(parts.startIndex ..< stringBreak.endIndex)
    return true
   }
   tokens.append(contentsOf: queue)
   let endCursor = cursor < parts.endIndex ? cursor : parts.endIndex
   parts.removeSubrange(parts.startIndex ..< endCursor)
   cursor += 1
   return true
  }
  return false
 }
}
