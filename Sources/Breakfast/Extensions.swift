@_exported import protocol Core.ExpressibleAsEmpty
@_exported import Extensions
public protocol SubSequential {
 associatedtype PreSequence: Collection
 init(_ sequence: PreSequence)
}

extension String.SubSequence: SubSequential {
 public typealias PreSequence = String
}

extension ArraySlice: SubSequential {
 public typealias PreSequence = [Element]
}

// MARK: - Extensions
public extension Collection
 where SubSequence: SubSequential, SubSequence.PreSequence == Self {
 @inlinable func partition(
  whereSeparator isSeparator: (Self.Element) throws -> Bool
 ) rethrows -> [SubSequence] {
  var parts: [SubSequence] = .empty
  if let firstIndex = try self.firstIndex(where: isSeparator) {
   let initialRange = self.startIndex ..< firstIndex
   let initialPart = self[initialRange]
   if !initialPart.isEmpty { parts.append(initialPart) }

   var cursor: Self.Index = self.index(after: firstIndex)
   parts.append(self[firstIndex ..< cursor])

   while let nextIndex = try self[cursor...].firstIndex(where: isSeparator) {
    let base = self[cursor ..< nextIndex]
    if !base.isEmpty { parts.append(base) }

    cursor = self.index(after: nextIndex)
    let part = self[nextIndex ..< cursor]
    parts.append(part)
   }

   if cursor < self.endIndex { parts.append(self[cursor...]) }
   return parts
  } else {
   return [SubSequence(self)]
  }
 }
}

public extension String {
 @inlinable static func * (lhs: Self, count: Int) -> Self {
  Self(repeating: lhs, count: count)
 }
}

extension BidirectionalCollection where Element: Equatable {
 @inlinable
 func `break`(from rhs: Element, to lhs: @escaping (Element) -> Bool) -> SubSequence? {
  guard let lastIndex = self.lastIndex(where: lhs) else { return nil }
  let sub = self[..<lastIndex]
  guard sub.last == rhs else { return sub.break(from: rhs, to: lhs) }
  return sub
 }

 func breakEven(from lhs: Element, to rhs: Element) -> SubSequence? {
  // requirements
  guard self.count > 1 else {
   return nil
  }
  guard let lowerBound = self.firstIndex(of: lhs) else {
   return nil
  }
  var cursor: Index = self.index(after: lowerBound)
  var `break`: Index?
  while cursor < endIndex {
   let character = self[cursor]
   let subdata = self[lowerBound ..< cursor]
   cursor = self.index(after: cursor)
   if character == rhs || character == lhs { `break` = cursor }
   guard subdata.count(for: lhs).isMultiple(of: 2) else { continue }
   break
  }
  return self[lowerBound ..< (`break` ?? cursor)]
 }
}

extension RangeReplaceableCollection {
 @discardableResult
 mutating func trimPrefix(while element: @escaping (Element) -> Bool) -> SubSequence? {
  guard let first, element(first) else { return nil }

  var index = self.startIndex
  while index < self.endIndex, element(self[index]) {
   index = self.index(after: index)
  }

  let subsequence = self[...index]
  let count = subsequence.count

  defer { self.removeFirst(count) }
  return subsequence
 }

 @discardableResult
 mutating func trimPrefix(of element: Element) -> SubSequence?
  where Element: Equatable {
  guard let first, first == element else { return nil }

  var index = self.startIndex
  while index < self.endIndex, self[index] == element {
   index = self.index(after: index)
  }

  let subsequence = self[..<index]

  let count = subsequence.count

  defer { self.removeFirst(count) }
  return subsequence
 }

 func prefix(of element: Element) -> SubSequence?
  where Element: Equatable {
  guard let first, first == element else { return nil }

  var index = self.startIndex
  while index < self.endIndex, self[index] == element {
   index = self.index(after: index)
  }
  return self[..<index]
 }
}

extension RangeReplaceableCollection
 where Self: MutableCollection & BidirectionalCollection {
 /// Add leading trivia to the tokens
 func getTrivia(for trivia: some Sequence<Element>) -> [ComponentData<Self>]?
  where Element: Equatable {
  var tokens: [ComponentData<Self>] = .empty
  var index = self.startIndex

  func get(_ tokens: inout [ComponentData<Self>]) -> [ComponentData<Self>]? {
   var current: [ComponentData<Self>] = .empty
   for element in trivia {
    let sub = self[index ..< endIndex]
    guard let trivial = sub.prefix(of: element) else { continue }
    current.append(.trivial(element, count: trivial.count))
    index = trivial.endIndex
   }

   if current.notEmpty { return current } else { return nil }
  }

  while let newTokens = get(&tokens) { tokens.append(contentsOf: newTokens) }
  return tokens.isEmpty ? nil : tokens
 }

 /// Trims leading trivia and adds it to the tokens
 @discardableResult
 mutating func removeTrivia(for trivia: some Sequence<Element>) -> [SubSequence]?
  where Element: Equatable {
  var items: [SubSequence] = .empty

  func remove(_ items: inout [SubSequence]) -> [SubSequence]? {
   var current: [SubSequence] = .empty
   for element in trivia {
    guard let trivial = self.trimPrefix(of: element) else { continue }
    current.append(trivial)
   }

   if current.notEmpty { return current } else { return nil }
  }

  while let newItems = remove(&items) { items.append(contentsOf: newItems) }
  return items.isEmpty ? nil : items
 }
}

public extension RangeReplaceableCollection
 where SubSequence: SubSequential, SubSequence.PreSequence == Self {
 mutating func dropFirst(_ int: Int) -> SubSequence {
  guard self.count > int else { return SubSequence(self) }
  let partIndex = self.index(self.startIndex, offsetBy: int)
  let substring = self[..<partIndex]
  self.removeFirst(int)
  return substring
 }
}
