@testable import Breakfast
import Benchmarks
import Testing

struct TestSyntaxProtocol {
 @Test(
  .disabled(
   """
   Partial implementation broken due to changes to 'RepeatSyntax'
   Please run /Scripts/testSyntax.swift with:
   https://github.com/acrlc/swift-shell to test, if needed.
   """
  )
 )
 func swiftCodeSyntax() async throws {
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
    var parser = SyntaxParser<String>(input, with: .backtickEscapedCode)
    try swift.parse(with: &parser).throwing()
    return parser.tokens
   }
  }
  try await displayBenchmark(benchmarks())
 }
}

@Test
func markdownSyntax() async throws {
 let input =
  #"""
  # Header
  ## Subheadline
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin turpis libero, congue in feugiat sed, rutrum quis dolor. Duis ex nisl, feugiat et nisl id, interdum hendrerit dolor. In nec libero felis. Aenean semper eget magna id feugiat. Curabitur dapibus ex quis semper iaculis. Cras efficitur ipsum ut nulla eleifend malesuada. Fusce massa orci, vulputate nec tellus pulvinar, ultrices tincidunt enim. Quisque nulla tortor, dictum vel aliquet eget, tincidunt eu est. Integer vitae libero sed urna feugiat sollicitudin a in est. Sed mollis magna sit amet tortor egestas, a tincidunt tellus maximus. Sed non ornare magna.
  [text source](https://www.lipsum.com/feed/html)
  <johndoe@me.com>
  """#

 let markdown = MarkdownSyntax()

 let benchmarks = Benchmarks {
  Measure(warmup: .zero, iterations: 1) {
   var parser = SyntaxParser<String>(input, with: markdown.lexer)
   try markdown.parse(with: &parser)//.throwing()
   return parser.tokens
  }
 }
 try await displayBenchmark(benchmarks())
}

func displayBenchmark(_ results: [Int: TimedResults]) throws {
 for offset in results.keys.sorted() {
  let result = results[offset]!
  let title = result.id ?? "benchmark " + (offset + 1).description
  let total = result.total
  let average = result.average
  print("time for \(title) was \(total)")
  print("average time for \(title) was \(average)")
  let warmupResult = results[0].unsafelyUnwrapped.results
  try #expect(
   #require(
    results.values
     .compactMap { $0.results as? [ComponentData<String>] }
   )
   .allSatisfy { $0.description == warmupResult.description }
  )
  print("results for \(title):\n \(warmupResult[0])\n")
 }
}
