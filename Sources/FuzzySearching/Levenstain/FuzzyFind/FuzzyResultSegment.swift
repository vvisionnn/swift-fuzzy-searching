import Foundation

public enum FuzzyResultSegment: Sendable {
	case gap([Character])
	case match([Character])

	func reversed() -> FuzzyResultSegment {
		switch self {
		case let .gap(array): return .gap(array.reversed())
		case let .match(array): return .match(array.reversed())
		}
	}

	var isEmpty: Bool {
		switch self {
		case let .gap(array), let .match(array): return array.isEmpty
		}
	}

	var asString: String {
		switch self {
		case let .gap(array), let .match(array): return String(array)
		}
	}

	var asGaps: String {
		switch self {
		case let .gap(array): return String(repeating: " ", count: array.count)
		case let .match(array): return String(repeating: "*", count: array.count)
		}
	}
}

extension FuzzyResultSegment: Equatable {}
