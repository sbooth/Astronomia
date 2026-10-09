//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A calendar day with the fraction of the day since midnight.
/// A calendar date is timescale-agnostic.
public struct CalendarDate: Hashable, Sendable {
	/// The calendar day.
	public let calendarDay: CalendarDay
	/// Fraction of the day elapsed since midnight in [0, 1).
	public let dayFraction: Double

	/// Creates a calendar date for the specified calendar day and day fraction.
	///
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the day fraction is not finite.
	///   - ``CalendarError/invalidDayFraction`` if the day fraction
	///     is outside the right-open interval [0, 1).
	public init(calendarDay: CalendarDay, dayFraction: Double) throws(CalendarError) {
		guard dayFraction.isFinite else { throw .nonFiniteValue }
		guard dayFraction >= 0, dayFraction < 1 else { throw .invalidDayFraction }
		self.calendarDay = calendarDay
		self.dayFraction = dayFraction == 0 ? 0 : dayFraction
	}

	/// Creates a calendar date for the specified year, month, and day in the given calendar
	/// with the specified day fraction.
	///
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the day fraction is not finite.
	///   - ``CalendarError/invalidDayFraction`` if the day fraction is outside
	///     the right-open interval [0, 1).
	///   - ``CalendarError/invalidDate`` if the year, month, and day do not form a valid
	///     date in the specified calendar.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the year, month, and day form
	///     a valid date, but its Julian day number cannot be represented as a ``JulianDayNumber``.
	public init(year: Int, month: Int, day: Int, dayFraction: Double, _ calendar: CalendarIdentifier) throws(CalendarError) {
		let calendarDay = try CalendarDay(year: year, month: month, day: day, calendar)
		try self.init(calendarDay: calendarDay, dayFraction: dayFraction)
	}
}

extension CalendarDate {
	/// Creates a calendar date from a calendar day and unchecked day fraction.
	init(calendarDay: CalendarDay, uncheckedDayFraction dayFraction: Double) {
		assert(dayFraction.isFinite, "Day fraction must be finite")
		assert(dayFraction >= 0 && dayFraction < 1, "Day fraction is outside the right-open interval [0, 1)")
		self.calendarDay = calendarDay
		self.dayFraction = dayFraction
	}
}

extension CalendarDate {
	/// The arithmetic year number. Year number 0 is 1 BCE.
	public var year: Int {
		calendarDay.year
	}

	/// The month number from `1` (January) to `12` (December).
	public var month: Int {
		calendarDay.month
	}

	/// The day number. The first day of the month is day number 1.
	public var day: Int {
		calendarDay.day
	}

	/// The calendar the year, month, and day belong to.
	public var calendar: CalendarIdentifier {
		calendarDay.calendar
	}

	/// The Julian day number of this calendar date's day.
	///
	/// This is the JDN of the calendar day (the day beginning at noon on that date),
	/// regardless of the day fraction. For a day fraction below 0.5 it is one greater than
	/// the floor of the instant's Julian Date.
	public var julianDayNumber: JulianDayNumber {
		calendarDay.julianDayNumber
	}
}

extension CalendarDate {
	/// Returns the calendar date the specified number of days plus day fraction before (for
	/// negative values) or after (for positive values) this calendar date, in the same calendar.
	///
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the day fraction is not finite.
	///   - ``CalendarError/invalidDayFraction`` if the day fraction is outside
	///     the right-open interval [0, 1).
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the resulting day's Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public func adding(days: Int, dayFraction: Double = 0) throws(CalendarError) -> CalendarDate {
		guard dayFraction.isFinite else { throw .nonFiniteValue }
		guard dayFraction >= 0, dayFraction < 1 else { throw .invalidDayFraction }

		var fraction = dayFraction + self.dayFraction

		var calendarDay: CalendarDay
		if fraction >= 1 {
			fraction -= 1
			if days < Int.max {
				calendarDay = try self.calendarDay.adding(days: days + 1)
			} else {
				calendarDay = try self.calendarDay.adding(days: days)
				calendarDay = try calendarDay.adding(days: 1)
			}
		} else {
			calendarDay = try self.calendarDay.adding(days: days)
		}

		return CalendarDate(calendarDay: calendarDay, uncheckedDayFraction: fraction)
	}

	/// Returns the calendar date the specified number of days before (for negative values) or after
	/// (for positive values) this calendar date, in the same calendar.
	///
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the number of days is not finite.
	///   - ``CalendarError/dayCountNotRepresentable`` if the number of whole days cannot
	///     be represented as an `Int`.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the resulting day's Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public func adding(days n: Double) throws(CalendarError) -> CalendarDate {
		guard n.isFinite else { throw .nonFiniteValue }
		guard let (days, fraction) = n.floorAndFraction else { throw .dayCountNotRepresentable }
		return try adding(days: days, dayFraction: fraction)
	}
}

extension CalendarDate {
	/// Creates a calendar date from a possibly out-of-range day fraction.
	///
	/// - Note: Day fractions outside [0, 1) carry whole days forward or backward
	///   from the specified calendar day.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the day fraction is not finite.
	///   - ``CalendarError/dayCountNotRepresentable`` if the day fraction's whole days cannot
	///     be represented as an `Int`.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the resulting day's Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public static func normalized(calendarDay: CalendarDay, dayFraction: Double) throws(CalendarError) -> CalendarDate {
		try CalendarDate(calendarDay: calendarDay, uncheckedDayFraction: 0).adding(days: dayFraction)
	}

	/// Creates a calendar date from possibly out-of-range month, day, and day fraction values.
	///
	/// - Note: Months outside `[1, 12]` roll over into earlier or later years, days are counted
	///   from the normalized month, and the day fraction carries whole days.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the day fraction is not finite.
	///   - ``CalendarError/dayCountNotRepresentable`` if the day fraction's whole days cannot
	///     be represented as an `Int`.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number for the
	///     year, month, and day cannot be represented as a ``JulianDayNumber`` or the
	///     resulting day's Julian day number cannot be represented as a ``JulianDayNumber``.
	public static func normalized(year: Int, month: Int, day: Int, dayFraction: Double, _ calendar: CalendarIdentifier) throws(CalendarError) -> CalendarDate {
		let calendarDay = try CalendarDay.normalized(year: year, month: month, day: day, calendar)
		return try normalized(calendarDay: calendarDay, dayFraction: dayFraction)
	}
}

extension CalendarDate {
	/// The timescale-agnostic decimal year for this calendar date.
	///
	/// The fraction is the number of days elapsed since midnight on January 1, including the day
	/// fraction, divided by the number of days in the year. For example, noon on January 1, 1985 is
	/// 1985 + 0.5/365 ≈ 1985.0014.
	///
	/// - Note: This is a calendar-based value, not an astronomical epoch such as a Julian or Besselian
	///   epoch; the same instant can have slightly different decimal years in different calendars.
	public var decimalYear: Double {
		Double(year) + (Double(calendarDay.dayOfYear - 1) + dayFraction) / Double(calendarDay.numberOfDaysInYear)
	}
}

extension CalendarDate {
	/// Returns the same calendar date expressed in another calendar.
	public func convertedTo(_ other: CalendarIdentifier) -> CalendarDate {
		CalendarDate(calendarDay: calendarDay.convertedTo(other), uncheckedDayFraction: dayFraction)
	}

	/// Returns `true` if the specified calendar date denotes the same day and time of day,
	/// regardless of calendar.
	public func isSameInstantAs(_ other: CalendarDate) -> Bool {
		calendarDay.isSameDayAs(other.calendarDay) && dayFraction == other.dayFraction
	}
}

extension CalendarDate: Comparable {
	public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
		if lhs.calendarDay.isSameDayAs(rhs.calendarDay), lhs.dayFraction != rhs.dayFraction {
			return lhs.dayFraction < rhs.dayFraction
		}
		// `CalendarDay` breaks JDN ties by calendar
		return lhs.calendarDay < rhs.calendarDay
	}
}

extension CalendarDate: CustomStringConvertible {
	public var description: String {
		"\(year)-\(month)-\(day) +\(dayFraction) (\(calendar.name))"
	}
}

extension CalendarDate: CustomDebugStringConvertible {
	public var debugDescription: String {
		"CalendarDate(year: \(year), month: \(month), day: \(day), dayFraction: \(dayFraction), calendar: \(calendar.name))"
	}
}

extension CalendarDate: Codable {
	private enum CodingKeys: String, CodingKey {
		case year, month, day, dayFraction, calendar
	}

	/// Decodes and validates a calendar date.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let year = try container.decode(Int.self, forKey: .year)
		let month = try container.decode(Int.self, forKey: .month)
		let day = try container.decode(Int.self, forKey: .day)
		let dayFraction = try container.decode(Double.self, forKey: .dayFraction)
		let calendar = try container.decode(CalendarIdentifier.self, forKey: .calendar)

		do throws(CalendarError) {
			self = try CalendarDate(year: year, month: month, day: day, dayFraction: dayFraction, calendar)
		} catch .nonFiniteValue {
			throw DecodingError.dataCorruptedError(forKey: .dayFraction, in: container, debugDescription: "Day fraction must be finite")
		} catch .invalidDayFraction {
			throw DecodingError.dataCorruptedError(forKey: .dayFraction, in: container, debugDescription: "Day fraction is outside the right-open interval [0, 1)")
		} catch .invalidDate {
			throw DecodingError.dataCorruptedError(forKey: .day, in: container, debugDescription: "year: \(year), month: \(month), day: \(day) do not form a valid \(calendar.name) date")
		} catch .julianDayNumberNotRepresentable {
			throw DecodingError.dataCorruptedError(forKey: .year, in: container, debugDescription: "The Julian day number for year: \(year), month: \(month), day: \(day) cannot be represented in the \(calendar.name) calendar")
		}
	}

	/// Encodes a calendar date.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(year, forKey: .year)
		try container.encode(month, forKey: .month)
		try container.encode(day, forKey: .day)
		try container.encode(dayFraction, forKey: .dayFraction)
		try container.encode(calendar, forKey: .calendar)
	}
}
