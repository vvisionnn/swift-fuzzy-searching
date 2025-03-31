import Foundation

public struct Alignment {
	public let score: Score
	public let result: FuzzyResult

	static var empty: Alignment {
		Alignment(score: 0, result: .empty)
	}

	func combine(_ other: Alignment) -> Alignment {
		Alignment(
			score: score + other.score,
			result: result.merge(other.result)
		)
	}

	public func highlight() -> String {
		"""
		\(result.segments.map(\.asString).joined())
		\(result.segments.map(\.asGaps).joined())
		"""
	}

	public var asString: String {
		result.asString
	}
}

extension Alignment: Equatable {}
