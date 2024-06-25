import struct Core.EmptyID

/// The identifiable component of a syntactic language
public protocol Component: Identifiable, CustomStringConvertible {}
public extension Component {
 static func ~= (lhs: Self, rhs: some Component)throws -> Bool {
  lhs.description == rhs.description
 }
}

public extension Component where ID == EmptyID {
 var id: EmptyID { EmptyID(placeholder: description) }
}

public typealias AnyComponent = any Component

//public struct ErasedComponent: Component {
// public let id: AnyHashable
// public let description: String
// public init(_ component: some Component) {
//  id = component.id
//  description = component.description
// }
//}

public extension Component {
// @_transparent
// var erased: ErasedComponent {
//  ErasedComponent(self)
// }

 static func == (lhs: AnyComponent, rhs: AnyComponent)throws -> Bool {
  lhs.description == rhs.description
 }

 @inlinable
 internal static var typeName: String {
  String(String(describing: self).prefix(while: { $0 != "<" }))
 }

 @inlinable
 internal static var prefix: String {
  let str = Self.typeName
  if str.hasSuffix("Component") {
   return String(str.dropLast(9))
  } else {
   return str
  }
 }

 var description: String {
  let prefix = Self.prefix.lowercased()

  guard !(ID.self is EmptyID.Type), !(ID.self is Never.Type)
  else {
   return prefix
  }

  let id: String? = {
   if let id = self.id as? (any ExpressibleByNilLiteral) {
    nil ~= id ? nil : "\(id)"
   } else {
    "\(self.id)"
   }
  }()?.readableRemovingQuotes

  guard let id else {
   return prefix
  }
  let suffix = id.readableRemovingQuotes

  if suffix.isEmpty || suffix == "nil" {
   return prefix
  }

  return "\(prefix).\(suffix)"
 }
}

public struct UnknownComponent: Component {}

public extension Component where Self == UnknownComponent {
 static var unknown: Self { Self() }
}

public enum ComponentData<Base: Collection> {
 public typealias Index = Base.Index
 public typealias SubSequence = Base.SubSequence
 public typealias Element = Base.Element
 public enum SubData {
  case
   element(Element),
   sequence(SubSequence),
   slice(ArraySlice<SubSequence>)

  public var rangesRangeOrIndex: ([Range<Index>]?, Range<Index>?, Index?)? {
   switch self {
   // TODO: index element
   case .element: .none
   case .sequence(let subsequence):
    (nil, subsequence.range, nil)
   case .slice(let subsequences):
    (subsequences.map(\.range), nil, nil)
   }
  }
 }

 case
  trivial(Element, count: Int = 1),
  element(Element),
  sequence(SubSequence),
  slice(ArraySlice<SubSequence>),
  component(AnyComponent, with: SubData),
  delimiter(
   from: AnyComponent = .unknown, to: AnyComponent = .unknown, with: Element
  ),
  parameter(AnyComponent = .unknown, with: SubData)

 public var rangesRangeOrIndex: ([Range<Index>]?, Range<Index>?, Index?)? {
  switch self {
  case .trivial: .none
  case .sequence(let subsequence): (nil, subsequence.range, nil)
  case .slice(let subsequences): (subsequences.map(\.range), nil, nil)
  case .component(_, let subdata): subdata.rangesRangeOrIndex
  case .delimiter: .none
  case .parameter(_, let subdata): subdata.rangesRangeOrIndex
  case .element: .none
  }
 }
}

extension ComponentData.SubData: CustomDebugStringConvertible
 where Base: CustomDebugStringConvertible,
 Base.SubSequence: CustomDebugStringConvertible,
 Base.Element: CustomDebugStringConvertible {
 public var debugDescription: String {
  switch self {
  case .sequence(let sequence): sequence.debugDescription
  case .slice(let subsequences): subsequences.debugDescription
  case .element(let element): element.debugDescription
  }
 }
}

extension ComponentData: CustomDebugStringConvertible
 where Base: CustomDebugStringConvertible,
 Base.SubSequence: CustomDebugStringConvertible,
 Base.Element: CustomDebugStringConvertible {
 public var debugDescription: String {
  switch self {
  case .trivial(let element, let count):
   "\(element.debugDescription), count: \(count)"
  case .sequence(let subsequence):
   "\(subsequence.debugDescription), as: unknown"
  case .slice(let subsequences):
   "\(subsequences.debugDescription), as: unknown"
  case .component(let component, let subdata):
   "\(subdata.debugDescription), as: \(component.description)"
  case .delimiter(let lhs, let rhs, let element):
   "\(element.debugDescription), from: \(lhs), to: \(rhs)"
  case .parameter(let component, let parameter):
   "\(parameter.debugDescription), as: \(component.description)"
  case .element(let element): "\(element.debugDescription), as: unknown"
  }
 }
}

public extension ComponentData<String>.SubData {
 var string: String {
  switch self {
  case .element(let character): String(character)
  case .sequence(let substring): String(substring)
  case .slice(let slice): slice.joined()
  }
 }
}

public extension ComponentData<String> {
 @inlinable
 var string: String {
  switch self {
  case .trivial(let char, let count):
   String(repeating: char, count: count)
  case .sequence(let substring): String(substring)
  case .slice(let slice): slice.joined()
  case .component(_, let subdata): subdata.string
  case .delimiter(_, _, let character): String(character)
  case .parameter(_, let parameter): parameter.string
  case .element(let character): String(character)
  }
 }

 @inlinable
 var component: AnyComponent {
  switch self {
  case .trivial: .trivial
  case .sequence: .unknown
  case .slice: .unknown
  case .component(let component, _): component
  case .delimiter: .delimiter
  case .parameter(let component, _): component
  case .element: .unknown
  }
 }
}
