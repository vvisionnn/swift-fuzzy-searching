import Foundation

public struct FuseProp: Sendable {
	public let value: String
	public let weight: Double

	public init(_ value: String, weight: Double = 1.0) {
		self.value = value

		self.weight = weight
	}
}
