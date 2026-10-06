//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The reasons a year, month, and day cannot form a `CalendarDay`.
public enum CalendarDayError: Error, Hashable, Sendable {
	/// The year, month, and day do not form a valid date, such as February 30.
	case invalidDate
	/// The year, month, and day form a valid date, but its Julian day number cannot be
	/// represented as a ``JulianDayNumber``.
	case julianDayNumberOutOfRange
}

/// A valid year, month, and day together with the calendar they belong to.
///
/// Equality is structural; a Julian date and a Gregorian date denoting the same day are not equal.
/// Use ``isSameDayAs(_:)`` to compare days across calendars.
public struct CalendarDay: Sendable {
	/// The arithmetic year number. Year number 0 is 1 BCE.
	public let year: Int
	/// The month number from `1` (January) to `12` (December).
	public let month: Int
	/// The day number. The first day of the month is day number 1.
	public let day: Int
	/// The calendar the year, month, and day belong to.
	public let calendar: CalendarIdentifier
	/// The Julian day number of this calendar day.
	public let julianDayNumber: JulianDayNumber

	/// Creates a calendar day for the specified year, month, and day in the given calendar.
	///
	/// - Throws:
	///   - ``CalendarDayError/invalidDate`` if the year, month, and day do not form a valid
	///     date in the specified calendar.
	///   - ``CalendarDayError/julianDayNumberOutOfRange`` if the year, month, and day form a valid
	///     date, but its Julian day number cannot be represented as a ``JulianDayNumber``.
	public init(year: Int, month: Int, day: Int, _ calendar: CalendarIdentifier) throws(CalendarDayError) {
		guard calendar.isValid(year: year, month: month, day: day) else {
			throw .invalidDate
		}

		guard let J = try? calendar.julianDayNumberFrom(year: year, month: month, day: day) else {
			throw .julianDayNumberOutOfRange
		}

		self.year = year
		self.month = month
		self.day = day
		self.calendar = calendar
		self.julianDayNumber = J
	}

	/// Creates the calendar day corresponding to the specified Julian day number
	/// in the given calendar.
	public init(julianDayNumber J: JulianDayNumber,_ calendar: CalendarIdentifier) {
		(year, month, day) = calendar.dateFromJulianDayNumber(J)
		self.calendar = calendar
		julianDayNumber = J
	}

	/// Creates a calendar day from possibly out-of-range month and day values.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years. Out-of-range
	///   days are counted forward or backward from the normalized year and month.
	/// - Throws: ``JulianDayNumberOutOfRangeError`` if the Julian day number for the year, month,
	///   and day cannot be represented as a ``JulianDayNumber``.
	public static func normalized(year: Int, month: Int, day: Int, _ calendar: CalendarIdentifier) throws(JulianDayNumberOutOfRangeError) -> CalendarDay {
		CalendarDay(julianDayNumber: try calendar.julianDayNumberFrom(year: year, month: month, day: day), calendar)
	}
}

extension CalendarDay {
	/// The calendar day as a year, month, and day tuple, for interoperability
	/// with the static calendar APIs.
	public var components: YearMonthDay {
		(year, month, day)
	}
}

extension CalendarDay {
	/// `true` if this calendar day falls in a leap year of its calendar.
	public var isInLeapYear: Bool {
		calendar.isLeapYear(year)
	}
}

extension CalendarDay {
	/// The number of months in one year.
	///
	/// - Note: This is independent of calendar.
	public var numberOfMonthsInYear: Int {
		JulianCalendar.numberOfMonthsInYear
	}

	/// The number of days in this calendar day's month.
	public var numberOfDaysInMonth: Int {
		calendar.numberOfDaysIn(month: month, year: year)
	}

	/// The number of days in this calendar day's year.
	public var numberOfDaysInYear: Int {
		calendar.numberOfDaysInYear(year)
	}
}

extension CalendarDay {
	/// The day of the week from 1 (Sunday) to 7 (Saturday).
	///
	/// - Note: This is independent of calendar.
	public var dayOfWeek: Int {
		JulianCalendar.dayOfWeek(julianDayNumber)
	}
}

extension CalendarDay {
	/// Returns the same calendar day expressed in another calendar.
	public func convertedTo(_ other: CalendarIdentifier) -> CalendarDay {
		other == calendar ? self : CalendarDay(julianDayNumber: julianDayNumber, other)
	}

	/// Returns `true` if the specified calendar day denotes the same day as this calendar day,
	/// regardless of calendar.
	public func isSameDayAs(_ other: CalendarDay) -> Bool {
		julianDayNumber == other.julianDayNumber
	}
}

extension CalendarDay {
	/// Returns the calendar day the specified number of days before (for negative values) or after
	/// (for positive values) this calendar day, in the same calendar.
	///
	/// - Throws: ``JulianDayNumberOutOfRangeError`` if the resulting calendar day's
	///   Julian day number cannot be represented as a ``JulianDayNumber``.
	public func adding(days n: Int) throws(JulianDayNumberOutOfRangeError) -> CalendarDay {
		if n == 0 {
			return self
		}
		let (J, overflow) = julianDayNumber.addingReportingOverflow(n)
		guard !overflow else {
			throw JulianDayNumberOutOfRangeError()
		}
		return CalendarDay(julianDayNumber: J, calendar)
	}

	/// Returns the number of days from this calendar day to the specified calendar day.
	///
	/// - Throws: ``JulianDayNumberOutOfRangeError`` if the difference between the two
	///   calendar days' Julian day numbers cannot be represented as an `Int`.
	public func days(to other: CalendarDay) throws(JulianDayNumberOutOfRangeError) -> Int {
		let (difference, overflow) = other.julianDayNumber.subtractingReportingOverflow(julianDayNumber)
		guard !overflow else {
			throw JulianDayNumberOutOfRangeError()
		}
		return difference
	}
}

extension CalendarDay: Hashable {
	public static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
		lhs.julianDayNumber == rhs.julianDayNumber && lhs.calendar == rhs.calendar
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(calendar)
		hasher.combine(julianDayNumber)
	}
}

private extension CalendarIdentifier {
	/// Tie-breaking order used by `CalendarDay`'s `Comparable` conformance.
	var sortOrder: Int {
		switch self {
		case .julian:
			return 0
		case .gregorian:
			return 1
		case .julianGregorian:
			return 2
		}
	}
}

extension CalendarDay: Comparable {
	/// Chronological order, with ties (the same day in different calendars) broken by calendar.
	public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
		let (l, r) = (lhs.julianDayNumber, rhs.julianDayNumber)
		return l != r ? l < r : lhs.calendar.sortOrder < rhs.calendar.sortOrder
	}
}

extension CalendarDay: CustomStringConvertible {
	public var description: String {
		"year: \(year), month: \(month), day: \(day) (\(calendar.name))"
	}
}

extension CalendarDay: Codable {
	private enum CodingKeys: String, CodingKey {
		case year, month, day, calendar
	}

	/// Decodes and validates a calendar day.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let year = try container.decode(Int.self, forKey: .year)
		let month = try container.decode(Int.self, forKey: .month)
		let day = try container.decode(Int.self, forKey: .day)
		let calendar = try container.decode(CalendarIdentifier.self, forKey: .calendar)

		do throws(CalendarDayError) {
			self = try CalendarDay(year: year, month: month, day: day, calendar)
		} catch .invalidDate {
			throw DecodingError.dataCorruptedError(forKey: .day, in: container, debugDescription: "year: \(year), month: \(month), day: \(day) is not a valid \(calendar.name) date")
		} catch .julianDayNumberOutOfRange {
			throw DecodingError.dataCorruptedError(forKey: .year, in: container, debugDescription: "The Julian day number for year: \(year), month: \(month), day: \(day) (\(calendar.name)) cannot be represented")
		}
	}
}
