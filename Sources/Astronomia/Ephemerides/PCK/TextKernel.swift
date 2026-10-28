//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A SPICE text kernel: the variables it assigns, by name.
///
/// A text kernel assigns values to variables in its data, between `\begindata` and `\begintext`
/// lines; the rest of the file is comments. A variable's values are numbers, strings in single
/// quotes, or dates after `@`, alone or in parentheses, separated by spaces or commas. `=`
/// assigns a variable's values, and `+=` appends to them. Numbers may have an exponent of `E`
/// or `D`, as in Fortran.
///
/// PCKs, frame kernels, and leap second kernels are text kernels; a ``PCKFile`` reads one.
///
/// See NAIF's Kernel Required Reading.
struct TextKernel: Hashable, Sendable {
	/// An error of a kernel's syntax.
	struct SyntaxError: Error, Hashable {
		/// The number of the line, from 1, where the data can't be read, or where an
		/// assignment that doesn't end starts.
		let line: Int
	}

	/// A variable's value.
	enum Value: Hashable, Sendable {
		/// A number.
		case number(Double)
		/// A string.
		case string(String)
		/// A date, as written after `@`.
		case date(String)
	}

	/// The variables' values by name.
	let variables: [String: [Value]]

	/// Reads a text kernel from its text.
	///
	/// - Parameter text: The kernel's text.
	/// - Throws: A ``SyntaxError`` if its data can't be read.
	init(text: String) throws(SyntaxError) {
		var parser = Parser()
		var isData = false
		var number = 0
		// Lines end with LF or CR LF, which is one character.
		for line in text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
			number += 1
			let trimmed = line.trimmingWhitespace
			if trimmed == "\\begindata" || trimmed == "\\begintext" {
				guard parser.isIdle else { throw SyntaxError(line: parser.start) }
				isData = trimmed == "\\begindata"
			} else if isData {
				guard parser.read(line, number: number) else { throw SyntaxError(line: number) }
			}
		}
		guard parser.isIdle else { throw SyntaxError(line: parser.start) }
		variables = parser.variables
	}

	/// Returns the numbers of a variable.
	///
	/// - Parameter name: The variable's name, as `BODY399_RADII`.
	/// - Returns: The numbers, or `nil` if the kernel doesn't assign the variable or its
	///   values aren't all numbers; dates aren't converted to numbers, as SPICE converts them.
	func numbers(named name: String) -> [Double]? {
		guard let values = variables[name] else { return nil }
		var numbers: [Double] = []
		for value in values {
			guard case let .number(number) = value else { return nil }
			numbers.append(number)
		}
		return numbers
	}

	/// A reader of assignments, which may span lines.
	struct Parser {
		/// What the parser expects next.
		enum State {
			/// A variable's name, or the end of the line.
			case name
			/// `=` or `+=` after a name.
			case assignment(String)
			/// A value or `(` after an assignment.
			case value(String, isAppending: Bool)
			/// A value, `,`, or `)` in a list.
			case list(String, isAppending: Bool)
		}

		/// The variables read.
		var variables: [String: [Value]] = [:]
		/// What the parser expects next.
		var state = State.name
		/// The values of the list being read.
		var values: [Value] = []
		/// The number of the line where the last assignment starts, at its name.
		var start = 0

		/// Whether the parser is between assignments.
		var isIdle: Bool {
			if case .name = state { true } else { false }
		}

		/// Assigns or appends a variable's values.
		mutating func assign(_ name: String, _ values: [Value], isAppending: Bool) {
			if isAppending {
				variables[name, default: []] += values
			} else {
				variables[name] = values
			}
		}

		/// Reads a line of data.
		///
		/// - Parameters:
		///   - line: The line.
		///   - number: The line's number, from 1.
		/// - Returns: Whether the line can be read.
		mutating func read(_ line: Substring, number: Int) -> Bool {
			var rest = line[...]
			while true {
				rest = rest.drop { $0.isWhitespace }
				guard let first = rest.first else { return true }
				switch state {
				case .name:
					let name = rest.prefix { !$0.isWhitespace && $0 != "=" && $0 != "+" && $0 != "(" }
					guard !name.isEmpty else { return false }
					rest = rest.dropFirst(name.count)
					state = .assignment(String(name))
					start = number
				case let .assignment(name):
					if rest.hasPrefix("+=") {
						rest = rest.dropFirst(2)
						state = .value(name, isAppending: true)
					} else if first == "=" {
						rest = rest.dropFirst()
						state = .value(name, isAppending: false)
					} else {
						return false
					}
				case let .value(name, isAppending):
					if first == "(" {
						rest = rest.dropFirst()
						values = []
						state = .list(name, isAppending: isAppending)
					} else {
						guard let value = Self.value(&rest) else { return false }
						assign(name, [value], isAppending: isAppending)
						state = .name
					}
				case let .list(name, isAppending):
					if first == ")" {
						rest = rest.dropFirst()
						assign(name, values, isAppending: isAppending)
						values = []
						state = .name
					} else if first == "," {
						rest = rest.dropFirst()
					} else {
						guard let value = Self.value(&rest) else { return false }
						values.append(value)
					}
				}
			}
		}

		/// Reads a value from the start of some text: a string in single quotes, with `''` for
		/// a quote, a date after `@`, or a number.
		///
		/// - Returns: The value, or `nil` if the text doesn't start with one.
		static func value(_ text: inout Substring) -> Value? {
			if text.first == "'" {
				var string = ""
				var rest = text.dropFirst()
				while let character = rest.first {
					rest = rest.dropFirst()
					if character == "'" {
						guard rest.first == "'" else {
							text = rest
							return .string(string)
						}
						rest = rest.dropFirst()
					}
					string.append(character)
				}
				return nil
			}
			let token = text.prefix { !$0.isWhitespace && $0 != "," && $0 != ")" && $0 != "(" }
			guard !token.isEmpty else { return nil }
			text = text.dropFirst(token.count)
			if token.first == "@" {
				let date = token.dropFirst()
				return date.isEmpty ? nil : .date(String(date))
			}
			let normalized = String(token.map { $0 == "D" || $0 == "d" ? "E" : $0 })
			guard normalized.allSatisfy({ $0.isNumber || "+-.Ee".contains($0) }), let number = Double(normalized), number.isFinite else {
				return nil
			}
			return .number(number)
		}
	}
}

extension Substring {
	/// The substring without its leading and trailing whitespace.
	fileprivate var trimmingWhitespace: Substring {
		var trimmed = self
		while trimmed.first?.isWhitespace == true {
			trimmed.removeFirst()
		}
		while trimmed.last?.isWhitespace == true {
			trimmed.removeLast()
		}
		return trimmed
	}
}
