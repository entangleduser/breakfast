@testable import Breakfast
import Benchmarks
import XCTest

final class BreakfastTests: XCTestCase {
 func testSwift() async throws {
  throw XCTSkip(
   """
   Partial implementation broken due to changes to 'RepeatSyntax'
   Please run /Scripts/testSyntax.swift with:
   https://github.com/acrlc/swift-shell to test, if needed.
   """
  )
  let input =
   #"""
   #!usr/bin/env swift shell
   let str = "Hello \(<redacted>)"
   class HelloWorld: Equatable {}
   let str = "Some message"
   var name: String = "Swift"
   var interpolated: Substring = "Hello \(name)"
   /*   Allow comment highlighting (dimming)   */
   var int = 0
   var dec = 0.0
   """#

  let swift = SwiftCodeSyntax()

  let benchmarks = Benchmarks {
   Measure(warmup: .zero, iterations: 1) {
    var parser = BaseParser<String>(input, with: .backtickEscapedCode)
    var parts = parser.parts
    var cursor = parser.cursor
    var tokens: [ComponentData<String>] = .empty
    try swift.apply(
     &tokens, with: &parts, at: &cursor, trivial: parser.lexer.trivial
    )
    return tokens
   }
  }
  try await displayBenchmark(benchmarks())
 }

 func displayBenchmark(_ results: [Int: TimedResults]) {
  for offset in results.keys.sorted() {
   let result = results[offset]!
   let title = result.id ?? "benchmark " + (offset + 1).description
   let total = result.total
   let average = result.average
   print("time for \(title) was \(total)")
   print("average time for \(title) was \(average)")
   let warmupResult = results[0].unsafelyUnwrapped.results
   XCTAssert(
    try XCTUnwrap(
     results.values
      .compactMap { $0.results as? [ComponentData<String>] }
    )
    .allSatisfy { $0.description == warmupResult.description }
   )
   print("results for \(title):\n \(warmupResult[0])\n")
  }
 }
}
