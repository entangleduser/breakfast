import Components
import struct Foundation.URL

/// A trivial syntax implementation for markdown, which is intended to be
/// extended into more flexible rendering solutions.
public struct MarkdownSyntax: SyntaxProtocol {
 public typealias Base = String
 public typealias Components = [AnySyntax<String>]
 public var components: Components {
  Repeat {
   Header()
   Link()
   Email()
   Body()
   Remaining(component: .unknown)
  }
  Remaining(component: .unknown)
 }

 var lexer: BaseParser<String>.Lexer = .withTrivia([.newline, .space]) {
  $0.isWhitespace || ["[", "]", "(", ")", "<", ">"].contains($0)
 }

 public static let minimal = Self()

 /// The statically rendered markdown components
 public static func renderTokens(
  from input: String, with self: Self = .minimal
 ) throws -> [Token] {
  var tokens: [Token] = .empty
  var parts: [Substring] = self.lexer(input)
  var index: Int = .zero
  do {
   try self.apply(
    &tokens,
    with: &parts,
    at: &index,
    trivial: self.lexer.trivial
   )
  } catch {
   print(error)
  }

  return tokens
 }

 public static func renderHTML(
  from input: String, with self: Self = .minimal
 ) throws -> String {
  let tokens = try renderTokens(from: input, with: self)
  return tokens.compactMap {
   guard let component = $0.component as? MarkdownComponent else { return nil }
   let fragment = component.fragment(from: $0.string.htmlSafe)
   if component.isHeader {
    return fragment
   } else {
    return fragment.appending("<br>")
   }
  }.joined(separator: .newline)
 }
}

public struct OffsetSyntax<Base: Collection>: SyntaxProtocol
 where Base.SubSequence: Equatable {
 var amount: Int = 1

 init(_ amount: Int = 1) {
  self.amount = amount
 }

 public func apply(
  _ tokens: inout [ComponentData<Base>],
  with parts: inout [Base.SubSequence],
  at cursor: inout Int,
  trivial: [Base.SubSequence]
 ) throws -> Bool {
  cursor += amount
  return true
 }
}

extension SyntaxProtocol {
 typealias Offset = OffsetSyntax<Base>
}

// MARK: Canonical Syntax
public enum MarkdownComponent: Identifiable, Component {
 case header(Int), codeBlock(String?), body, link(String?, URL?), email(String)
 public var id: String {
  switch self {
  case .header(let depth): "h\(depth)"
  case .codeBlock(let id):
   if let id { "codeblock.\(id)" } else { "codeblock" }
  case .body: "body"
  case .link: "link"
  case .email: "email"
  }
 }

 var isHeader: Bool {
  switch self {
  case .header: true
  default: false
  }
 }

 func fragment(from string: String) -> String {
  switch self {
  case .codeBlock(let id):
   let tag = if let id {
    "code class=\"\(id)\""
   } else {
    "code"
   }
   return "<pre><\(tag)>" + string + "</code></pre>"
  case .header(let depth):
   let tag = "h\(depth)"

   return "<\(tag)>" + string + "</\(tag)>"
  case .body:

   return "<div>" + string
    .replacingOccurrences(of: "\n", with: "<br>") + "</div>"
  case .link(let label, let url):
   let tag = if let url {
    "<a href=\"\(url)\">"
   } else {
    "<a>"
   }

   return {
    if let label {
     tag + label
    } else {
     tag
    }
   }() + "</a>"

  case .email(let address):
   return "<a href=\"mailto:\(address)\">\(address)</a>"
  }
 }
}

public extension Component where Self == MarkdownComponent {
 static var markdown: Self.Type { Self.self }
}

struct MarkdownBodySyntax: SyntaxProtocol {
 typealias Base = String
 typealias Components = [AnySyntax<String>]

 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  while ["\n", " "].contains(parts[cursor]) {
   cursor += 1
  }

  guard cursor < parts.endIndex else { return false }
  guard !["#", "```"].contains(where: { parts[cursor].hasPrefix($0) }) else {
   return true
  }
  let oldIndex = cursor

  while
   cursor < parts.endIndex {
   if
    let index = parts[cursor...].firstIndex(
     where: { $0 == "\n" }
    ) {
    // body needs to stop at the next newline to support newline delimited links
    // and emails as well
    guard !["#", "```", "\n"].contains(where: { parts[cursor].hasPrefix($0) })
    else {
     break
    }
    cursor = index + 1
   } else {
    cursor = parts.endIndex
   }
  }

  tokens.append(
   .component(MarkdownComponent.body, with: .slice(parts[oldIndex ..< cursor]))
  )
  return true
 }
}

extension MarkdownSyntax {
 typealias Body = MarkdownBodySyntax
}

struct MarkdownHeaderSyntax: SyntaxProtocol {
 typealias Base = String
 typealias Components = [AnySyntax<String>]
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  while ["\n", " "].contains(parts[cursor]) {
   cursor += 1
  }

  let first = parts[cursor]
  guard first.hasPrefix("#") else {
   return false
  }

  let index = first.firstIndex(where: { $0 != "#" }) ?? first.endIndex
  let depth = first[..<index].count
  let captureIndex =
   parts[cursor...].firstIndex(where: { $0 == "\n" }) ?? parts.endIndex

  let content = parts[cursor ..< captureIndex]

  switch depth {
  case 7...: break
  default:
   tokens.append(
    .component(
     MarkdownComponent.header(depth), with:
     .slice(
      content.dropFirst()
       .drop(while: { $0 == " " })
     )
    )
   )
  }

  cursor += content.count

  return true
 }
}

extension MarkdownSyntax {
 typealias Header = MarkdownHeaderSyntax
}

struct MarkdownCodeblockSyntax: SyntaxProtocol {
 typealias Base = String
 typealias Components = [AnySyntax<String>]
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  while ["\n", " "].contains(parts[cursor]) {
   cursor += 1
  }

  guard cursor < (parts.endIndex - 1) else {
   return false
  }

  let first = parts[cursor]
  guard first.hasPrefix("```") else {
   return false
  }

  let oldIndex = cursor
  if
   let matchIndex = parts[(cursor + 1)...].firstIndex(where: { $0 == "```" }),
   parts[matchIndex - 1] == "\n" {
   cursor = matchIndex + 1

   let id: String? = if
    let splitIndex = first
     .firstIndex(where: { $0 != "`" }) {
    String(first[splitIndex...])
   } else {
    nil
   }

   tokens.append(
    .component(
     MarkdownComponent.codeBlock(id),
     with: .slice(parts[(oldIndex + 2) ..< (cursor - 2)])
    )
   )
  } else {
   return false
  }
  return true
 }
}

extension MarkdownSyntax {
 typealias Codeblock = MarkdownCodeblockSyntax
}

struct MarkdownLinkSyntax: SyntaxProtocol {
 typealias Base = String
 typealias Components = [AnySyntax<String>]
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  while ["\n", " "].contains(parts[cursor]) {
   cursor += 1
  }

  let first = parts[cursor]
  guard
   first == "[",
   let labelBreak = parts[cursor...].break(from: "[", to: "]"),
   !labelBreak.contains("\n"),
   let linkBreak = parts[labelBreak.endIndex...]
    .break(from: "(", to: ")"), !linkBreak.contains("\n") else {
   return false
  }

  let label: String? = if labelBreak.count > 2 {
   labelBreak[(labelBreak.startIndex + 1) ..< (labelBreak.endIndex - 1)]
    .joined()
  } else {
   nil
  }

  let url: String? = if linkBreak.count > 2 {
   linkBreak[(linkBreak.startIndex + 1) ..< (linkBreak.endIndex - 1)].joined()
  } else {
   nil
  }

  tokens.append(
   .component(
    MarkdownComponent.link(
     label, url == nil ? nil : URL(string: url!)
    ),
    with: .slice(labelBreak + linkBreak)
   )
  )

  cursor = linkBreak.endIndex + 1

  return true
 }
}

extension MarkdownSyntax {
 typealias Link = MarkdownLinkSyntax
}

struct MarkdownEmailSyntax: SyntaxProtocol {
 typealias Base = String
 typealias Components = [AnySyntax<String>]
 public func apply(
  _ tokens: inout [ComponentData<String>],
  with parts: inout [Substring],
  at cursor: inout Int,
  trivial: [Substring]
 ) throws -> Bool {
  while ["\n", " "].contains(parts[cursor]) {
   cursor += 1
  }

  let first = parts[cursor]

  guard
   first == "<",
   let addressBreak = parts[cursor...].break(from: "<", to: ">"),
   !addressBreak.contains("\n") else {
   return false
  }

  guard
   addressBreak.count > 2 else {
   return false
  }

  let address =
   addressBreak[(addressBreak.startIndex + 1) ..< (addressBreak.endIndex - 1)]
    .joined()

  guard address.contains(regex: \.email) else { return false }

  tokens.append(
   .component(
    MarkdownComponent.email(address),
    with: .slice(addressBreak)
   )
  )

  cursor = addressBreak.endIndex + 1

  return true
 }
}

extension MarkdownSyntax {
 typealias Email = MarkdownEmailSyntax
}

// MARK: - String Utilitiess
extension StringProtocol {
 var htmlSafe: String {
  replacingOccurrences(of: "<", with: "&lt;")
   .replacingOccurrences(of: ">", with: "&gt;")
   .replacingOccurrences(of: "\\", with: "&#92;")
 }
}

extension String {
 @inlinable
 func contains(regex pattern: KeyPath<Regex, String>) -> Bool {
  range(
   of: Self.regex[keyPath: pattern], options: [.regularExpression]
  ) != nil
 }

 @inlinable
 func matches(regex pattern: KeyPath<Regex, String>) -> Bool {
  guard
   let matchingRange = range(
    of: Self.regex[keyPath: pattern], options: [.regularExpression]
   ) else { return false }
  let range = range
  return range == matchingRange || range.overlaps(matchingRange)
 }
}
