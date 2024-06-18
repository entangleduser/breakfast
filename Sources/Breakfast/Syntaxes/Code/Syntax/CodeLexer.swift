public extension BaseParser.Lexer where Base == String {
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

public extension BaseParser where Base == String {
 static func code(_ base: Base) -> Self {
  Self(base, with: .code)
 }
 
 static func backtickEscapedCode(_ base: Base) -> Self {
  Self(base, with: .backtickEscapedCode)
 }
}

