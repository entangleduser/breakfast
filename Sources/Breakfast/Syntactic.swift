@resultBuilder
public enum SyntaxBuilder<Base: ParseableSequence> {
 public typealias Component = any SyntaxProtocol<Base>
 public typealias Components = [Component]
 public static func buildBlock(_ components: Component...) -> Components {
  components
 }
 
 public static func buildArray(_ components: [Component]) -> Components {
  components
 }
 
 public static func buildEither(first: Component?) -> Components {
  first == nil ? .empty : [first.unsafelyUnwrapped]
 }
 
 public static func buildEither(second: Component?) -> Components {
  second == nil ? .empty : [second.unsafelyUnwrapped]
 }
 
 public static func buildOptional(_ optional: Component?) -> Components {
  optional == nil ? .empty : [optional.unsafelyUnwrapped]
 }
 
 public static func buildLimitedAvailability(
  _ components: Components
 ) -> Components {
  components
 }
}
