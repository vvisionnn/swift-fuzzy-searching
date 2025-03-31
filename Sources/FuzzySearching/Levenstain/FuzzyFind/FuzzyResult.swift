import Foundation

public struct FuzzyResult: Sendable {
	public let segments: [FuzzyResultSegment]

	public var asString: String {
		segments.map(\.asString).joined()
	}

	static func match(_ a: Character) -> FuzzyResult {
		FuzzyResult(segments: [.match([a])])
	}

	static func gap(_ a: Character) -> FuzzyResult {
		FuzzyResult(segments: [.gap([a])])
	}

	static func gaps(_ str: String) -> FuzzyResult {
		FuzzyResult(segments: str.reversed().map { char in
			FuzzyResultSegment.gap([char])
		})
	}

	static let empty: FuzzyResult = .init(segments: [])

	func reversed() -> FuzzyResult {
		FuzzyResult(segments: segments.map { segment in
			segment.reversed()
		}.reversed())
	}

	func combine(_ other: FuzzyResult) -> FuzzyResult {
		if let last = segments.last, let first = other.segments.first {
			if last.isEmpty {
				return FuzzyResult(segments: segments.lead).combine(other)
			} else if first.isEmpty {
				return combine(FuzzyResult(segments: other.segments.tail))
			} else if case let .gap(l) = last, case let .gap(h) = first {
				return FuzzyResult(segments: segments.lead + [.gap(l + h)] + other.segments.tail)
			} else if case let .match(l) = last, case let .match(h) = first {
				return FuzzyResult(segments: segments.lead + [.match(l + h)] + other.segments.tail)
			} else {
				return FuzzyResult(segments: segments + other.segments)
			}
		} else {
			return isEmpty ? other : self
		}
	}

	func merge(_ other: FuzzyResult) -> FuzzyResult {
		if isEmpty { return other }
		if other.isEmpty { return self }
		let xs = segments[0]
		let ys = other.segments[0]
		switch (xs, ys) {
		case let (.gap(g1), .gap(g2)):
			if g1.count <= g2.count {
				return FuzzyResult(segments: [.gap(g1)]).combine(
					tail.merge(other.drop(g1.count))
				)
			} else {
				return FuzzyResult(segments: [.gap(g2)]).combine(
					drop(g2.count).merge(other.tail)
				)
			}
		case let (.match(m1), .match(m2)):
			if m1.count >= m2.count {
				return FuzzyResult(segments: [.match(m1)]).combine(
					tail.merge(other.drop(m1.count))
				)
			} else {
				return FuzzyResult(segments: [.match(m2)]).combine(
					drop(m2.count).merge(other.tail)
				)
			}
		case let (.gap(_), .match(m)):
			return FuzzyResult(segments: [.match(m)]).combine(
				drop(m.count).merge(other.tail)
			)
		case let (.match(m), .gap(_)):
			return FuzzyResult(segments: [.match(m)]).combine(
				tail.merge(other.drop(m.count))
			)
		}
	}

	private func drop(_ n: Int) -> FuzzyResult {
		guard n >= 1 else { return self }
		if let first = segments.first {
			switch first {
			case let .gap(array):
				if n >= array.count {
					return tail.drop(n - array.count)
				} else {
					return FuzzyResult(segments: [.gap(array.drop(n))]).combine(tail)
				}
			case let .match(array):
				if n >= array.count {
					return tail.drop(n - array.count)
				} else {
					return FuzzyResult(segments: [.match(array.drop(n))]).combine(tail)
				}
			}
		} else {
			return .empty
		}
	}

	private var isEmpty: Bool {
		segments.isEmpty
	}

	private var tail: FuzzyResult {
		FuzzyResult(segments: segments.tail)
	}

	private var lead: FuzzyResult {
		FuzzyResult(segments: segments.lead)
	}
}

extension FuzzyResult: Equatable {}

extension Array {
	fileprivate func drop(_ n: Int) -> Array {
		Array(dropFirst(n))
	}

	fileprivate var tail: Array {
		if isEmpty { return [] }
		return Array(dropFirst())
	}

	fileprivate var lead: Array {
		if isEmpty { return [] }
		return Array(dropLast())
	}
}
