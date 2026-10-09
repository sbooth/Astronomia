//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A valid year, month, and day together with the calendar they belong to.
///
/// Equality is structural; a Julian date and a Gregorian date denoting the same day are not
/// equal. Use ``isSameDayAs(_:)`` to compare days across calendars.
public struct CalendarDay: Sendable {
	/// The arithmetic year number. Year number 0 is 1 BCE.
	public let year: Int
	/// The month number from 1 (January) to 12 (December).
	public let month: Int
	/// The day number. The first day of the month is day number 1.
	public let day: Int
	/// The calendar the year, month, and day belong to.
	public let calendar: CalendarIdentifier
	/// The Julian day number of this calendar day.
	public let julianDayNumber: JulianDayNumber

	/// Creates a calendar day for the specified year, month, and day in the given calendar.
	///
	/// - Parameters:
	///   - year: The arithmetic year number. Year number 0 is 1 BCE.
	///   - month: The month number from 1 (January) to 12 (December).
	///   - day: The day number, starting at 1.
	///   - calendar: The calendar the year, month, and day belong to.
	/// - Throws:
	///   - ``CalendarError/invalidDate`` if the year, month, and day do not form a valid date
	///     in the specified calendar.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the year, month, and day form
	///     a valid date, but its Julian day number cannot be represented as a
	///     ``JulianDayNumber``.
	public init(year: Int, month: Int, day: Int, _ calendar: CalendarIdentifier) throws(CalendarError) {
		guard calendar.isValid(year: year, month: month, day: day) else { throw .invalidDate }
		let J = try calendar.julianDayNumberFrom(year: year, month: month, day: day)

		self.year = year
		self.month = month
		self.day = day
		self.calendar = calendar
		self.julianDayNumber = J
	}

	/// Creates the calendar day corresponding to the specified Julian day number
	/// in the given calendar.
	///
	/// - Parameters:
	///   - J: The Julian day number. Every ``JulianDayNumber`` value is valid.
	///   - calendar: The calendar in which to express the day.
	public init(julianDayNumber J: JulianDayNumber, _ calendar: CalendarIdentifier) {
		(year, month, day) = calendar.dateFromJulianDayNumber(J)
		self.calendar = calendar
		julianDayNumber = J
	}

	/// Creates a calendar day from possibly out-of-range month and day values.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	///   See ``JulianGregorianCalendar/julianDayNumberFromDate(_:)`` for how out-of-range
	///   values are interpreted in the Julian-Gregorian calendar.
	/// - Parameters:
	///   - year: The arithmetic year number. Year number 0 is 1 BCE.
	///   - month: The month number, possibly outside the closed interval [1, 12].
	///   - day: The day number, possibly outside the days of the month.
	///   - calendar: The calendar the year, month, and day belong to.
	/// - Returns: A calendar day with valid components in `calendar`.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the year, month, and day cannot be represented as a ``JulianDayNumber``.
	public static func normalized(year: Int, month: Int, day: Int, _ calendar: CalendarIdentifier) throws(CalendarError) -> CalendarDay {
		try CalendarDay(julianDayNumber: calendar.julianDayNumberFrom(year: year, month: month, day: day), calendar)
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
	///
	/// In the Julian-Gregorian calendar, October 1582 has 21 days.
	public var numberOfDaysInMonth: Int {
		try! calendar.numberOfDaysIn(month: month, year: year)
	}

	/// The number of days in this calendar day's year.
	///
	/// In the Julian-Gregorian calendar, 1582 has 355 days.
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
	/// The day of year (ordinal day) for this calendar day, starting at 1.
	public var dayOfYear: Int {
		calendar.dayOfYearFromJulianDayNumber(julianDayNumber)
	}

	/// The decimal year for the start of this calendar day.
	///
	/// The fraction is the number of whole days elapsed since January 1 divided by the number
	/// of days in the year, so January 1, 1985 is 1985.0 and July 2, 1985 is
	/// 1985 + 182/365 ≈ 1985.4986.
	///
	/// - Note: This is a calendar-based value, not an astronomical epoch such as a Julian or
	///   Besselian epoch; the same day can have slightly different decimal years in different
	///   calendars.
	public var decimalYear: Double {
		Double(year) + Double(dayOfYear - 1) / Double(numberOfDaysInYear)
	}
}

extension CalendarDay {
	/// Returns the same calendar day expressed in another calendar.
	///
	/// - Parameter other: The calendar in which to express the day.
	/// - Returns: A calendar day with the same Julian day number in `other`.
	public func convertedTo(_ other: CalendarIdentifier) -> CalendarDay {
		other == calendar ? self : CalendarDay(julianDayNumber: julianDayNumber, other)
	}

	/// Returns `true` if the specified calendar day denotes the same day as this calendar day,
	/// regardless of calendar.
	///
	/// - Parameter other: The calendar day to compare with.
	/// - Returns: `true` if both calendar days have the same Julian day number; otherwise, `false`.
	public func isSameDayAs(_ other: CalendarDay) -> Bool {
		julianDayNumber == other.julianDayNumber
	}
}

extension CalendarDay {
	/// Returns the calendar day the specified number of days before (for negative values) or
	/// after (for positive values) this calendar day, in the same calendar.
	///
	/// - Parameter n: The signed number of days to add.
	/// - Returns: The resulting calendar day, in this calendar day's calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the resulting calendar
	///   day's Julian day number cannot be represented as a ``JulianDayNumber``.
	public func adding(days n: Int) throws(CalendarError) -> CalendarDay {
		if n == 0 {
			return self
		}
		let (J, overflow) = julianDayNumber.addingReportingOverflow(n)
		guard !overflow else { throw .julianDayNumberNotRepresentable }
		return CalendarDay(julianDayNumber: J, calendar)
	}

	/// Returns the number of days from this calendar day to the specified calendar day.
	///
	/// The result is positive if `other` is later, and is independent of either calendar.
	///
	/// - Parameter other: The end of the span.
	/// - Returns: The number of days from this calendar day to `other`, positive if `other` is
	///   later.
	/// - Throws: ``CalendarError/dayCountNotRepresentable`` if the difference between the two
	///   calendar days' Julian day numbers cannot be represented as an `Int`.
	public func days(to other: CalendarDay) throws(CalendarError) -> Int {
		let (difference, overflow) = other.julianDayNumber.subtractingReportingOverflow(julianDayNumber)
		guard !overflow else { throw .dayCountNotRepresentable }
		return difference
	}
}

extension CalendarDay: Hashable {
	/// Returns `true` if the two calendar days denote the same day in the same calendar.
	///
	/// - Returns: `true` if both calendar days have the same Julian day number and calendar;
	///   otherwise, `false`.
	public static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
		lhs.julianDayNumber == rhs.julianDayNumber && lhs.calendar == rhs.calendar
	}

	/// Hashes the calendar and Julian day number into the specified hasher.
	///
	/// - Parameter hasher: The hasher to use when combining the components of this instance.
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
	/// Chronological order, with ties (the same day in different calendars) broken by
	/// calendar.
	///
	/// - Returns: `true` if `lhs` is earlier than `rhs`, or if they denote the same day and the
	///   calendar of `lhs` sorts before that of `rhs`; otherwise, `false`.
	public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
		let (l, r) = (lhs.julianDayNumber, rhs.julianDayNumber)
		return l != r ? l < r : lhs.calendar.sortOrder < rhs.calendar.sortOrder
	}
}

extension CalendarDay: CustomStringConvertible {
	/// A textual representation of the calendar day, such as `2000-1-1 (Gregorian)`.
	public var description: String {
		"\(year)-\(month)-\(day) (\(calendar.name))"
	}
}

extension CalendarDay: CustomDebugStringConvertible {
	/// A textual representation of the calendar day's components, suitable for debugging.
	public var debugDescription: String {
		"CalendarDay(year: \(year), month: \(month), day: \(day), calendar: \(calendar.name))"
	}
}

extension CalendarDay: Codable {
	private enum CodingKeys: String, CodingKey {
		case year, month, day, calendar
	}

	/// Creates a calendar day by decoding and validating it from the specified decoder.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: `DecodingError.dataCorrupted` if the decoded values do not form a valid
	///   calendar day, or any error thrown by `decoder`.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let year = try container.decode(Int.self, forKey: .year)
		let month = try container.decode(Int.self, forKey: .month)
		let day = try container.decode(Int.self, forKey: .day)
		let calendar = try container.decode(CalendarIdentifier.self, forKey: .calendar)

		do throws(CalendarError) {
			self = try CalendarDay(year: year, month: month, day: day, calendar)
		} catch .invalidDate {
			throw DecodingError.dataCorruptedError(forKey: .day, in: container, debugDescription: "year: \(year), month: \(month), day: \(day) do not form a valid \(calendar.name) date")
		} catch .julianDayNumberNotRepresentable {
			throw DecodingError.dataCorruptedError(forKey: .year, in: container, debugDescription: "The Julian day number for year: \(year), month: \(month), day: \(day) cannot be represented in the \(calendar.name) calendar")
		}
	}
}
