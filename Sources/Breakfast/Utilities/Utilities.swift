/// Represents a source location in a Swift file.
public struct SourceLocation: Hashable, Codable, Sendable {
 /// The line in the file where this location resides. 1-based.
 ///
 /// - SeeAlso: ``SourceLocation/presumedLine``
 public var line: Int

 /// The UTF-8 byte offset from the beginning of the line where this location
 /// resides. 1-based.
 public let column: Int

 /// The UTF-8 byte offset into the file where this location resides.
 public let offset: Int

 /// The file in which this location resides.
 ///
 /// - SeeAlso: ``SourceLocation/presumedFile``
 public let file: String

 /// The line of this location when respecting `#sourceLocation` directives.
 ///
 /// If the location hasn’t been adjusted using `#sourceLocation` directives,
 /// this is the same as `line`.
 public let presumedLine: Int

 /// The file in which the location resides when respecting `#sourceLocation`
 /// directives.
 ///
 /// If the location has been adjusted using `#sourceLocation` directives, this
 /// is the file mentioned in the last `#sourceLocation` directive before this
 /// location, otherwise this is the same as `file`.
 public let presumedFile: String

 /// Create a new source location at the specified `line` and `column` in
 /// `file`.
 ///
 /// - Parameters:
 ///   - line: 1-based, i.e. the first line in the file has line number 1
 ///   - column: The UTF-8 byte offset of the location with its line, i.e. the
 ///             number of bytes all characters in the line before the location
 ///             occupy when encoded as UTF-8. 1-based, i.e. the leftmost
 ///             column in the file has column 1.
 ///   - offset: The UTF-8 offset of the location within the entire file, i.e.
 ///             the number of bytes all source code before the location
 ///             occupies when encoded as UTF-8. 0-based, i.e. the first
 ///             location in the source file has `offset` 0.
 ///   - file: A string describing the name of the file in which this location
 ///           is contained.
 ///   - presumedLine: If the location has been adjusted using `#sourceLocation`
 ///                   directives, the adjusted line. If `nil`, this defaults to
 ///                   `line`.
 ///   - presumedFile: If the location has been adjusted using `#sourceLocation`
 ///                   directives, the adjusted file. If `nil`, this defaults to
 ///                   `file`.
 public init(
  line: Int,
  column: Int,
  offset: Int,
  file: String,
  presumedLine: Int? = nil,
  presumedFile: String? = nil
 ) {
  self.line = line
  self.offset = offset
  self.column = column
  self.file = file
  self.presumedLine = presumedLine ?? line
  self.presumedFile = presumedFile ?? file
 }
}

/// Represents a half-open range in a Swift file.
public struct SourceRange: Hashable, Codable, Sendable {
 /// The beginning location of the source range.
 ///
 /// This location is included in the range
 public let start: SourceLocation

 /// The end location of the source range.
 ///
 /// The location of the character after the end of the range,
 /// ie. this location is not included in the range.
 public let end: SourceLocation

 /// Construct a new source range, starting at `start` (inclusive) and ending
 /// at `end` (exclusive).
 public init(start: SourceLocation, end: SourceLocation) {
  self.start = start
  self.end = end
 }
}
