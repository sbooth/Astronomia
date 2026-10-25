//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation

/// Returns the rows of a text fixture, each parsed by a closure.
///
/// A text fixture is a file in `Fixtures` with one row per line and its fields separated by
/// spaces. Empty lines and lines starting with `#` are skipped. Large fixtures are text, read
/// when first used, because the compiler takes minutes and gigabytes to type-check the same
/// rows as Swift literals.
///
/// A missing file, a file without rows, or a row with a field that doesn't parse, too few
/// fields, or too many, stops the tests with the file and line, so that a fixture can't be
/// read as empty and pass the checks that loop over its rows.
///
/// - Parameters:
///   - name: The name of the file, without the `.txt` extension.
///   - parse: Returns a row from its fields, read in order.
/// - Returns: The rows, in the order of the file.
func textFixture<Row>(_ name: String, _ parse: (inout TextFixtureRow) -> Row) -> [Row] {
	guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures") else {
		fatalError("Missing text fixture Fixtures/\(name).txt")
	}
	let text: String
	do {
		text = try String(contentsOf: url, encoding: .utf8)
	} catch {
		fatalError("Can't read Fixtures/\(name).txt: \(error)")
	}
	let rows = textFixture(name, text: text, parse)
	if rows.isEmpty {
		fatalError("Fixtures/\(name).txt has no rows")
	}
	return rows
}

/// Returns the rows of the text of a text fixture, each parsed by a closure.
///
/// Lines end with any newline, as a line feed, or a carriage return and a line feed where Git
/// or Python on Windows writes them: in Swift a carriage return and a line feed are one
/// `Character`, which a split on `"\n"` wouldn't match.
///
/// - Parameters:
///   - name: The name of the file, for messages.
///   - text: The text of the file.
///   - parse: Returns a row from its fields, read in order.
/// - Returns: The rows, in the order of the text.
func textFixture<Row>(_ name: String, text: String, _ parse: (inout TextFixtureRow) -> Row) -> [Row] {
	var rows: [Row] = []
	for (index, line) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
		guard !line.isEmpty, !line.hasPrefix("#") else { continue }
		var row = TextFixtureRow(name: name, line: index + 1, fields: line.split(separator: " "))
		rows.append(parse(&row))
		if !row.isAtEnd {
			row.fail("more fields than the row has")
		}
	}
	return rows
}

/// The fields of a row of a text fixture, read in order.
struct TextFixtureRow {
	/// The name of the file.
	let name: String
	/// The line of the row in the file, from 1.
	let line: Int
	/// The fields.
	private let fields: [Substring]
	/// The index of the next field.
	private var index = 0

	init(name: String, line: Int, fields: [Substring]) {
		self.name = name
		self.line = line
		self.fields = fields
	}

	/// Whether every field has been read.
	var isAtEnd: Bool {
		index == fields.count
	}

	/// Stops the tests with the file, line, and a message.
	func fail(_ message: String) -> Never {
		fatalError("Fixtures/\(name).txt:\(line): \(message)")
	}

	/// Returns the next field.
	mutating func field() -> Substring {
		guard index < fields.count else { fail("fewer fields than the row has") }
		defer { index += 1 }
		return fields[index]
	}

	/// Returns the next field as a number.
	mutating func double() -> Double {
		let field = field()
		guard let value = Double(field) else { fail("\(field) isn't a number") }
		return value
	}

	/// Returns the next field as a number, or `nil` if it is `nil`.
	mutating func optionalDouble() -> Double? {
		if index < fields.count, fields[index] == "nil" {
			index += 1
			return nil
		}
		return double()
	}

	/// Returns the next field as an integer.
	mutating func int() -> Int {
		let field = field()
		guard let value = Int(field) else { fail("\(field) isn't an integer") }
		return value
	}

	/// Returns the next field, `true` or `false`, as a Boolean.
	mutating func bool() -> Bool {
		switch field() {
		case "true": true
		case "false": false
		case let field: fail("\(field) isn't true or false")
		}
	}

	/// Returns the next three fields as a vector.
	mutating func vector() -> [Double] {
		[double(), double(), double()]
	}

	/// Returns the case of an enumeration named by the next field, as `newMoon` for
	/// `Moon.PhaseEvent.Kind.newMoon`.
	mutating func value<T: CaseIterable>(_ type: T.Type = T.self) -> T {
		let field = field()
		guard let value = T.allCases.first(where: { String(describing: $0) == field }) else {
			fail("\(field) isn't a case of \(T.self)")
		}
		return value
	}
}
