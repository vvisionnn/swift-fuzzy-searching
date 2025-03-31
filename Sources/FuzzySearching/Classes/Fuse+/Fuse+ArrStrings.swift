import Foundation

extension Fuse {
	/// Searches for a text pattern in an array of srings
	///
	/// - Parameters:
	///   -   text: The pattern string to search for
	///   - aList: The list of string in which to search
	/// - Returns: A tuple containing the `item` in which the match is found, the `score`, and the `ranges` of the matched characters
	public func searchSync(_ text: String, in aList: [String]) -> [SrchDetails] {
		let pattern = createPattern(from: text)

		var items = [SrchDetails]()

		for (index, item) in aList.enumerated() {
			if let result = search(pattern, in: item) {
				items.append((index, result.score, result.ranges))
			}
		}

		return items.sorted { $0.diffScore < $1.diffScore }
	}

	/// Asynchronously searches for a text pattern in an array of srings.
	///
	/// - Parameters:
	///   - text: The pattern string to search for
	///   - aList: The list of string in which to search
	///   - chunkSize: The size of a single chunk of the array. For example, if the array has `1000` items, it may be useful to split the work into 10 chunks of 100. This should ideally speed up the search logic. Defaults to `100`.
	///   - completion: The handler which is executed upon completion
	public func search(_ text: String, in aList: [String], chunkSize: Int = 100) async -> [SrchDetails] {
		await withCheckedContinuation { continuation in
			search(text, in: aList, chunkSize: chunkSize) { results in
				continuation.resume(returning: results)
			}
		}
	}

	/// Asynchronously searches for a text pattern in an array of srings.
	///
	/// - Parameters:
	///   - text: The pattern string to search for
	///   - aList: The list of string in which to search
	///   - chunkSize: The size of a single chunk of the array. For example, if the array has `1000` items, it may be useful to split the work into 10 chunks of 100. This should ideally speed up the search logic. Defaults to `100`.
	///   - completion: The handler which is executed upon completion
	public func search(
		_ text: String,
		in aList: [String],
		chunkSize: Int = 100,
		completion: @escaping @Sendable ([SrchDetails]) -> Void
	) {
		let pattern = createPattern(from: text)

		var items = [SrchDetails]()
		let itemsLock = NSLock()
		let group = DispatchGroup()

		aList.splitBy(chunkSize).enumerated().forEach { chunkIndex, chunk in
			group.enter()

			self.searchQueue.async {
				for (index, item) in chunk.enumerated() {
					if let result = self.search(pattern, in: item) {
						itemsLock.lock()
						items.append((chunkIndex * chunkSize + index, result.score, result.ranges))
						itemsLock.unlock()
					}
				}

				group.leave()
			}
		}

		group.notify(queue: searchQueue) {
			let sorted = items.sorted { $0.diffScore < $1.diffScore }
			DispatchQueue.main.async {
				completion(sorted)
			}
		}
	}
}
