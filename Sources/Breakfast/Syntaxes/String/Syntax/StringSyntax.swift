public struct WordSyntax: SyntaxProtocol {
 public init() {}
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
