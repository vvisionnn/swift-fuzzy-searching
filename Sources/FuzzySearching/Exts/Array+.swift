
extension Array {
	internal func splitBy(_ chunkSize: Int) -> [ArraySlice<Element>] {
		stride(from: 0, to: count, by: chunkSize).map {
			self[$0 ..< Swift.min($0 + chunkSize, self.count)]
		}
	}
}
