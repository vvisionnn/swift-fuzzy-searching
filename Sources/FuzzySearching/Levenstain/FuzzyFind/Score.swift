import Foundation

public struct Score: ExpressibleByIntegerLiteral, Sendable {
	public let value: Int

	public init(integerLiteral value: Int) {
		self.value = value
	}

	public static let defaultMatch: Score = 16

	public static let defaultMismatch: Score = 0

	public static var defaultBoundary: Score {
		Score(integerLiteral: Score.defaultMatch.value / 2)
	}

	public static var defaultCamelCase: Score {
		Score(integerLiteral: Score.defaultBoundary.value - 1)
	}

	public static let defaultFirstCharBonusMultiplier: Int = 2

	public static func defaultGapPenalty(_ n: Int) -> Score {
		Score(integerLiteral: (n == 1) ? 3 : max(0, n + 3))
	}

	public static var defaultConsecutiveBonus: Score {
		defaultGapPenalty(8)
	}
}

extension Score: Equatable {}

func + (lhs: Score, rhs: Score) -> Score {
	Score(integerLiteral: lhs.value + rhs.value)
}

func - (lhs: Score, rhs: Score) -> Score {
	Score(integerLiteral: lhs.value - rhs.value)
}

func * (lhs: Int, rhs: Score) -> Score {
	Score(integerLiteral: lhs * rhs.value)
}

extension Score: Comparable {
	public static func < (lhs: Score, rhs: Score) -> Bool {
		lhs.value < rhs.value
	}
}
