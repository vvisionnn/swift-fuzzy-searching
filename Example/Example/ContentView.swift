import FuzzySearching
import SwiftUI

struct ContentView: View {
	let books: [String] = [
		"Angels & Demons",
		"Old Man's War",
		"The Lock Artist",
		"HTML5",
		"Right Ho Jeeves",
		"The Code of the Wooster",
		"Thank You Jeeves",
		"The DaVinci Code",
		"The Silmarillion",
		"Syrup",
		"The Lost Symbol",
		"The Book of Lies",
		"Lamb",
		"Fool",
		"Incompetence",
		"Fat",
		"Colony",
		"Backwards, Red Dwarf",
		"The Grand Design",
		"The Book of Samson",
		"The Preservationist",
		"Fallen",
		"Monster 1959",
	]
	@State private var results: [AttributedString] = []
	@State private var text = ""

	var body: some View {
		ScrollView {
			LazyVStack {
				ForEach(results.indices, id: \.self) { index in
					HStack {
						Text(results[index])
						Spacer(minLength: 0)
					}
					.background(
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.fill(Color(uiColor: .systemBackground))
					)
				}
			}
			.padding(.horizontal, 24)
		}
		.toolbar(content: {
			ToolbarItemGroup(placement: .principal) {
				TextField("Search", text: $text)
					.frame(maxWidth: .infinity)
					.padding(.horizontal, 14)
					.padding(.vertical, 12)
			}
		})
		.navigationBarTitleDisplayMode(.inline)
		.onAppear(perform: {
			results = books.map { AttributedString($0) }
		})
		.onChange(of: text) { _, value in
			Fuse().search(text, in: books) { results in
				if results.isEmpty, value.isEmpty {
					DispatchQueue.main.async {
						self.results = books.map { AttributedString($0) }
					}
					return
				}
				let updatedResults = results.map { index, _, matchedRanges in
					let book = books[index]
					let attributedString = NSMutableAttributedString(string: book)
					matchedRanges
						.map(Range.init)
						.map(NSRange.init)
						.forEach {
							let boldAttrs = [
								NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 17),
								NSAttributedString.Key.foregroundColor: UIColor.blue,
							]
							attributedString.addAttributes(boldAttrs, range: $0)
						}
					return AttributedString(attributedString)
				}

				DispatchQueue.main.async {
					self.results = updatedResults
				}
			}
		}
	}
}

@available(macOS 12, *)
func attributedString(_ fuzz: FuzzySrchResult, _ string: String) -> AttributedString {
	var attributedString = AttributedString(string)
	for result in fuzz.results {
		if result.value != string { continue }
		let ranges = result.ranges
		for range in ranges {
			// Convert CountableClosedRange<Int> to Range<AttributedString.Index>
			if let start = attributedString.index(at: range.lowerBound),
			   let end = attributedString.index(at: range.upperBound + 1) {
				let attributedRange = start ..< end

				// Apply attributes using AttributeContainer
				var container = AttributeContainer()
				container.foregroundColor = .red
				attributedString[attributedRange].setAttributes(container)
			}
		}
	}

	return attributedString
}

@available(macOS 12, *)
extension AttributedString {
	func index(at offset: Int) -> AttributedString.Index? {
		guard offset >= 0, offset <= characters.count else {
			return nil
		}
		return index(startIndex, offsetByCharacters: offset)
	}
}

#Preview {
	Color.clear
		.sheet(isPresented: .constant(true)) {
			NavigationStack {
				ContentView()
			}
			.interactiveDismissDisabled()
		}
		.transaction { transaction in
			transaction.animation = nil
			transaction.disablesAnimations = true
		}
}
