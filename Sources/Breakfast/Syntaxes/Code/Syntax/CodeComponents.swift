public enum CommentComponent: Component {
 case open, line, mark, todo, fixme, block, close
 public var id: String {
  switch self {
  case .open: "open"
  case .line: "line"
  case .mark: "mark"
  case .todo: "todo"
  case .fixme: "fixme"
  case .block: "block"
  case .close: "close"
  }
 }
}

public extension Component where Self == CommentComponent {
 static var comment: Self.Type { self }
}

public enum DocumentationComponent: Component {
 case open, line, block, close
 public var id: String {
  switch self {
  case .open: "open"
  case .line: "line"
  case .block: "block"
  case .close: "close"
  }
 }
}

public extension Component where Self == DocumentationComponent {
 static var documentation: Self.Type { self }
}

public struct DelimiterComponent: Component {
 public init() {}
 // TODO: incorporate specification on what's being delimited
}

public struct TrivialComponent: Component {
 public init() {}
}

public extension Component where Self == TrivialComponent {
 static var trivial: Self { Self() }
}

public extension Component where Self == DelimiterComponent {
 static var delimiter: Self { Self() }
}

public enum SymbolComponent: Component {
 case assignment
 public var id: String { "assignment" }
}

public extension Component where Self == SymbolComponent {
 static var symbol: Self.Type { self }
}

public enum BracketComponent: Component {
 case start, end
 public var id: String {
  switch self {
  case .start: "start"
  case .end: "end"
  }
 }
}

public extension Component where Self == BracketComponent {
 static var bracket: Self.Type { self }
}

public enum WordComponent: Component {
 case declaration(IdentifierComponent), control, unknown
 public var id: String {
  switch self {
  case .declaration(let component): "declaration." + component.id
  case .control: "control"
  case .unknown: "unknown"
  }
 }
}

public extension Component where Self == WordComponent {
 static var word: Self.Type { self }
}

public enum IdentifierComponent: Component, ExpressibleByStringLiteral {
 case `class`, `struct`, `protocol`, /* for typealias */ generic, property,
      function, key, path, imperative, unknown, custom(String)

 public init(stringLiteral text: String) {
  self = .custom(text)
 }

 public var id: String {
  switch self {
  case .class: "class"
  case .struct: "struct"
  case .protocol: "protocol"
  case .generic: "generic"
  case .property: "property"
  case .function: "function"
  case .key: "key"
  case .path: "path"
  case .imperative: "imperative"
  case .unknown: "unknown"
  case .custom(let string): string
  }
 }

 public init(_ id: some StringProtocol) {
  switch id {
  case "class": self = .class
  case "struct": self = .struct
  case "protocol": self = .protocol
  case "generic": self = .generic
  case "let", "var", "property": self = .property
  case "func", "function": self = .function
  default: fatalError("case for \(id) not covered")
  }
 }
}

public extension Component where Self == IdentifierComponent {
 static var identifier: Self.Type { self }
}

public enum StringComponent: Component {
 case open, literal, interpolated, escaped, `static`, close
 public var id: String {
  switch self {
  case .open: "open"
  case .literal: "literal"
  case .interpolated: "interpolated"
  case .escaped: "escaped"
  case .static: "static"
  case .close: "close"
  }
 }
}

public extension Component where Self == StringComponent {
 static var string: Self.Type { self }
}

public enum IntegerComponent: Component {
 case literal
 public var id: String {
  switch self {
  case .literal: "literal"
  }
 }
}

public extension Component where Self == IntegerComponent {
 static var integer: Self.Type { self }
}

public enum FloatComponent: Component {
 case literal
 public var id: String {
  switch self {
  case .literal: "literal"
  }
 }
}

public extension Component where Self == FloatComponent {
 static var float: Self.Type { self }
}

public enum TypeComponent: Component {
 case `class`, `struct`, `protocol`, generic, property, function, `extension`,
      imperative
 public var id: String {
  switch self {
  case .class: "class"
  case .struct: "struct"
  case .protocol: "protocol"
  case .generic: "generic"
  case .property: "property"
  case .function: "function"
  case .extension: "extension"
  case .imperative: "imperative"
  }
 }

 public init(_ id: some StringProtocol) {
  switch id {
  case "class": self = .class
  case "struct": self = .struct
  case "protocol": self = .protocol
  case "generic": self = .generic
  case "let", "var", "property": self = .property
  case "func", "function": self = .function
  default: fatalError("case for \(id) not covered")
  }
 }
}

public extension Component where Self == TypeComponent {
 static var type: Self.Type { self }
}

public enum PreprocessorComponent: Component {
 case hashbang, processor, argument
 public var id: String {
  switch self {
  case .hashbang: "hashbang"
  case .processor: "processor"
  case .argument: "argument"
  }
 }
}

public extension Component where Self == PreprocessorComponent {
 static var preprocessor: Self.Type { self }
}

// public enum IdentifierComponent: Component {
// case key
// public var id: String {
//  switch self {
//  case .key: "key"
//  }
// }
// }
//
// public extension Component where Self == IdentifierComponent {
// static var dot: Self.Type { self }
// }
