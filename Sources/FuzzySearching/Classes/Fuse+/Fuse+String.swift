import Foundation

extension Fuse {
	/// Searches for a pattern in a given string.
	///
	///     let fuse = Fuse()
	///     let pattern = fuse(from: "some text")
	///     fuse(pattern, in: "some string")
	///
	/// - Parameters:
	///   - pattern: The pattern to search for. This is created by calling `createPattern`
	///   - aString: The string in which to search for the pattern
	/// - Returns: A tuple containing a `score` between `0.0` (exact match) and `1` (not a match), and `ranges` of the matched characters. If no match is found will return nil.
	public func search(_ pattern: Pattern?, in aString: String) -> (score: Double, ranges: [CountableClosedRange<Int>])? {
		guard let pattern = pattern else {
			return nil
		}

		// If tokenize is set we will split the pattern into individual words and take the average which should result in more accurate matches
		if tokenize {
			// Split this pattern by the space character
			let wordPatterns = pattern.text.split(separator: " ").compactMap { createPattern(from: String($0)) }

			// Get the result for testing the full pattern string. If 2 strings have equal individual word matches this will boost the full string that matches best overall to the top
			let fullPatternResult = _search(pattern, in: aString)

			// Reduce all the word pattern matches and the full pattern match into a totals tuple
			let results = wordPatterns.reduce(into: fullPatternResult) { totalResult, pattern in

				let result = _search(pattern, in: aString)
				totalResult = (totalResult.score + result.score, totalResult.ranges + result.ranges)
			}

			// Average the total score by dividing the summed scores by the number of word searches + the full string search. Also remove any range duplicates since we are searching full string and words individually.
			let averagedResult = (
				score: results.score / Double(wordPatterns.count + 1),
				ranges: [CountableClosedRange<Int>](Set<CountableClosedRange<Int>>(results.ranges))
			)

			// If the averaged score is 1 then there were no matches so return nil. Otherwise return the average result
			return averagedResult.score == 1 ? nil : averagedResult

		} else {
			let result = _search(pattern, in: aString)

			// If the averaged score is 1 then there were no matches so return nil. Otherwise return the average result
			return result.score == 1 ? nil : result
		}
	}

	//// Searches for a pattern in a given string.
	///
	///     _search(pattern, in: "some string")
	///
	/// - Parameters:
	///   - pattern: The pattern to search for. This is created by calling `createPattern`
	///   - aString: The string in which to search for the pattern
	/// - Returns: A tuple containing a `score` between `0.0` (exact match) and `1` (not a match), and `ranges` of the matched characters. If no match is found will return a tuple with score of 1 and empty array of ranges.
	private func _search(_ pattern: Pattern, in aString: String) -> (score: Double, ranges: [CountableClosedRange<Int>]) {
		var text = aString

		if !isCaseSensitive {
			text = text.lowercased()
		}

		let textLength = text.count

		// Exact match
		if pattern.text == text {
			return (0, [0 ... textLength - 1])
		}

		let location = location
		let distance = distance
		var threshold = threshold

		var bestLocation: Int? = {
			if let index = text.index(of: pattern.text, startingFrom: location) {
				return text.distance(from: text.startIndex, to: index)
			}
			return nil
		}()

		// A mask of the matches. We'll use to determine all the ranges of the matches
		var matchMaskArr = [Int](repeating: 0, count: textLength)

		if let bestLoc = bestLocation {
			threshold = min(
				threshold,
				FuseUtilities.calculateScore(
					pattern.len,
					errorsInMatch: 0,
					matchLocation: location,
					expectedMatchLocation: bestLoc,
					distance: distance
				)
			)

			// What about in the other direction? (speed up)
			bestLocation = {
				if let index = text.lastIndexOf(pattern.text, position: location + pattern.len) {
					return text.distance(from: text.startIndex, to: index)
				}
				return nil
			}()

			if let bestLocation = bestLocation {
				threshold = min(
					threshold,
					FuseUtilities.calculateScore(
						pattern.len,
						errorsInMatch: 0,
						matchLocation: location,
						expectedMatchLocation: bestLocation,
						distance: distance
					)
				)
			}
		}

		bestLocation = nil
		var score = 1.0
		var binMax: Int = pattern.len + textLength
		var lastBitArr = [Int]()

		let textCount = text.count

		// Magic begins now
		for i in 0 ..< pattern.len {
			// Scan for the best match; each iteration allows for one more error.
			// Run a binary search to determine how far from the match location we can stray at this error level.
			var binMin = 0
			var binMid = binMax

			while binMin < binMid {
				if FuseUtilities.calculateScore(
					pattern.len,
					errorsInMatch: i,
					matchLocation: location,
					expectedMatchLocation: location + binMid,
					distance: distance
				) <= threshold {
					binMin = binMid
				} else {
					binMax = binMid
				}
				binMid = ((binMax - binMin) / 2) + binMin
			}

			// Use the result from this iteration as the maximum for the next.
			binMax = binMid
			var start = max(1, location - binMid + 1)
			let finish = min(location + binMid, textLength) + pattern.len

			// Initialize the bit array
			var bitArr = [Int](repeating: 0, count: finish + 2)

			//            bitArr[finish + 1] = (1 << i) - 1 // original string. Possible crashes in some cases because of arithmetic overflow
			let arithmeticOverflowSafeVal = (1 << i) == Int.min ? Int.min : (1 << i) - 1
			bitArr[finish + 1] = arithmeticOverflowSafeVal

			if start > finish {
				continue
			}

			var currentLocationIndex: String.Index?

			for j in (start ... finish).reversed() {
				let currentLocation = j - 1

				// Need to check for `nil` case, since `patternAlphabet` is a sparse hash
				let charMatch: Int = {
					if currentLocation < textCount {
						currentLocationIndex = currentLocationIndex.map { text.index(before: $0) } ?? text.index(
							text.startIndex,
							offsetBy: currentLocation
						)
						let char = text[currentLocationIndex!]
						if let result = pattern.alphabet[char] {
							return result
						}
					}
					return 0
				}()

				// A match is found
				if charMatch != 0 {
					matchMaskArr[currentLocation] = 1
				}

				// First pass: exact match
				bitArr[j] = ((bitArr[j + 1] << 1) | 1) & charMatch

				// Subsequent passes: fuzzy match
				if i > 0 {
					bitArr[j] |= (((lastBitArr[j + 1] | lastBitArr[j]) << 1) | 1) | lastBitArr[j + 1]
				}

				if (bitArr[j] & pattern.mask) != 0 {
					score = FuseUtilities.calculateScore(
						pattern.len,
						errorsInMatch: i,
						matchLocation: location,
						expectedMatchLocation: currentLocation,
						distance: distance
					)

					// This match will almost certainly be better than any existing match. But check anyway.
					if score <= threshold {
						// Indeed it is
						threshold = score
						bestLocation = currentLocation

						guard let bestLocation = bestLocation else {
							break
						}

						if bestLocation > location {
							// When passing `bestLocation`, don't exceed our current distance from the expected `location`.
							start = max(1, 2 * location - bestLocation)
						} else {
							// Already passed `location`. No point in continuing.
							break
						}
					}
				}
			}

			// No hope for a better match at greater error levels
			if FuseUtilities.calculateScore(
				pattern.len,
				errorsInMatch: i + 1,
				matchLocation: location,
				expectedMatchLocation: location,
				distance: distance
			) > threshold {
				break
			}

			lastBitArr = bitArr
		}

		return (score, FuseUtilities.findRanges(matchMaskArr))
	}

	/// Searches for a text pattern in a given string.
	///
	///     let fuse = Fuse()
	///     fuse.search("some text", in: "some string")
	///
	/// **Note**: if the same text needs to be searched across many strings, consider creating the pattern once via `createPattern`, and then use the other `search` function. This will improve performance, as the pattern object would only be created once, and re-used across every search call:
	///
	///     let fuse = Fuse()
	///     let pattern = fuse.createPattern(from: "some text")
	///     fuse.search(pattern, in: "some string")
	///     fuse.search(pattern, in: "another string")
	///     fuse.search(pattern, in: "yet another string")
	///
	/// - Parameters:
	///   - text: the text string to search for.
	///   - aString: The string in which to search for the pattern
	/// - Returns: A tuple containing a `score` between `0.0` (exact match) and `1` (not a match), and `ranges` of the matched characters.
	public func searchSync(_ text: String, in aString: String) -> (score: Double, ranges: [CountableClosedRange<Int>])? {
		search(createPattern(from: text), in: aString)
	}
}
