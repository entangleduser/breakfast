public extension SyntaxParser.Lexer where Base == String {
 static var code: Self {
  Self(trivial: [.space, .newline]) {
   $0.isPunctuation || $0.isSymbol || $0.isWhitespace || $0.isNewline
  }
 }

 static var backtickEscapedCode: Self {
  Self(trivial: [.space, .newline]) {
   ($0.isPunctuation && $0 != "`") || $0.isSymbol || $0.isWhitespace || $0.isNewline
  }
 }
}

public extension SyntaxParser where Base == String {
 static func code(_ base: Base) -> SyntaxParser<String> {
  SyntaxParser<String>(base, with: .code)
 }
 
 static func backtickEscapedCode(_ base: Base) -> SyntaxParser<String> {
  SyntaxParser<String>(base, with: .backtickEscapedCode)
 }
}

