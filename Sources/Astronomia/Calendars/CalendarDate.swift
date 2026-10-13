//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A calendar day with the fraction of the day elapsed since midnight.
///
/// A calendar date is timescale-agnostic: it is in the timescale of the Julian Date or other
/// value it was created from.
///
/// Equality is structural, so the same instant expressed in different calendars is not
/// equal. Use ``isSameInstantAs(_:)`` to compare instants across calendars.
public struct CalendarDate: Hashable, Sendable {
	/// The calendar day.
	public let calendarDay: CalendarDay
	/// The fraction of the day elapsed since midnight, in the right-open interval [0, 1).
	public let fractionSinceMidnight: Double

	/// Creates a calendar date for the specified calendar day and fraction since midnight.
	///
	/// A fraction since midnight of negative zero is stored as positive zero.
	///
	/// - Parameters:
	///   - calendarDay: The calendar day.
	///   - fractionSinceMidnight: The fraction of the day elapsed since midnight.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the fraction since midnight is not finite.
	///   - ``CalendarError/invalidDayFraction`` if the fraction since midnight
	///     is outside the right-open interval [0, 1).
	public init(calendarDay: CalendarDay, fractionSinceMidnight: Double) throws(CalendarError) {
		guard fractionSinceMidnight.isFinite else { throw .nonFiniteValue }
		guard fractionSinceMidnight >= 0, fractionSinceMidnight < 1 else { throw .invalidDayFraction }
		self.init(calendarDay: calendarDay, uncheckedFractionSinceMidnight: fractionSinceMidnight == 0 ? 0 : fractionSinceMidnight)
	}

	/// Creates a calendar date for the specified year, month, and day in the given calendar
	/// with the specified fraction since midnight.
	///
	/// - Parameters:
	///   - year: The arithmetic year number. Year number 0 is 1 BCE.
	///   - month: The month number from 1 (January) to 12 (December).
	///   - day: The day number, starting at 1.
	///   - fractionSinceMidnight: The fraction of the day elapsed since midnight.
	///   - calendar: The calendar the year, month, and day belong to.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the fraction since midnight is not finite.
	///   - ``CalendarError/invalidDayFraction`` if the fraction since midnight is outside
	///     the right-open interval [0, 1).
	///   - ``CalendarError/invalidDate`` if the year, month, and day do not form a valid
	///     date in the specified calendar.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the year, month, and day form
	///     a valid date, but its Julian day number cannot be represented as a
	///     ``JulianDayNumber``.
	public init(year: Int, month: Int, day: Int, fractionSinceMidnight: Double = 0, _ calendar: CalendarIdentifier) throws(CalendarError) {
		let calendarDay = try CalendarDay(year: year, month: month, day: day, calendar)
		try self.init(calendarDay: calendarDay, fractionSinceMidnight: fractionSinceMidnight)
	}
}

extension CalendarDate {
	/// Creates a calendar date from a calendar day and unchecked fraction since midnight.
	///
	/// - Precondition: `fractionSinceMidnight` is finite and in the right-open interval [0, 1).
	init(calendarDay: CalendarDay, uncheckedFractionSinceMidnight fractionSinceMidnight: Double) {
		assert(fractionSinceMidnight.isFinite, "Fraction since midnight must be finite")
		assert(fractionSinceMidnight >= 0 && fractionSinceMidnight < 1, "Fraction since midnight is outside the right-open interval [0, 1)")
		self.calendarDay = calendarDay
		self.fractionSinceMidnight = fractionSinceMidnight
	}
}

extension CalendarDate {
	/// The arithmetic year number. Year number 0 is 1 BCE.
	public var year: Int {
		calendarDay.year
	}

	/// The month number from 1 (January) to 12 (December).
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
	/// This is the JDN of the calendar day (the Julian day beginning at noon on that date),
	/// regardless of the fraction since midnight. For a fraction since midnight less than 0.5
	/// it is one greater than the floor of the instant's Julian Date.
	public var julianDayNumber: JulianDayNumber {
		calendarDay.julianDayNumber
	}
}

extension CalendarDate {
	/// Returns the calendar date the specified number of days plus fractional day before (for
	/// negative values) or after (for positive values) this calendar date, in the same
	/// calendar.
	///
	/// `days` may be negative but `fractionalDay` may not; to move back by a fraction of a day,
	/// use ``adding(days:)-(Double)`` or pass one fewer day and the complementary fraction.
	///
	/// - Parameters:
	///   - days: The signed number of whole days to add.
	///   - fractionalDay: The additional fraction of a day to add.
	/// - Returns: The resulting calendar date, in this calendar date's calendar.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the fractional day is not finite.
	///   - ``CalendarError/invalidDayFraction`` if the fractional day is outside
	///     the right-open interval [0, 1).
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the resulting day's Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public func adding(days: Int, fractionalDay: Double = 0) throws(CalendarError) -> CalendarDate {
		guard fractionalDay.isFinite else { throw .nonFiniteValue }
		guard fractionalDay >= 0, fractionalDay < 1 else { throw .invalidDayFraction }
		return try CalendarDate(calendar) { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(days)
			try acc.add(fractionalDay)
		}
	}

	/// Returns the calendar date the specified number of days before (for negative values) or
	/// after (for positive values) this calendar date, in the same calendar.
	///
	/// The time of day is computed from the exact sum and rounded once. `n` may exceed the
	/// range of `Int` if this calendar date offsets it.
	///
	/// - Parameter n: The signed number of days, including any fraction of a day, to add.
	/// - Returns: The resulting calendar date, in this calendar date's calendar.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the number of days is not finite.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the resulting day's Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public func adding(days n: Double) throws(CalendarError) -> CalendarDate {
		try CalendarDate(calendar) { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(n)
		}
	}
}

extension CalendarDate {
	/// Creates a calendar date in `calendar` from the exact sum of the terms that `body` adds
	/// to an empty accumulator, rounding the time of day once at the end.
	///
	/// The sum is a midnight-based day count: `J + f`, for `f` in [0, 1), is the instant `f`
	/// days after midnight at the start of the calendar day whose Julian day number is `J`.
	/// This differs from a Julian Date, which counts from noon, by half a day.
	///
	/// - Parameters:
	///   - calendar: The calendar in which to express the result.
	///   - body: A closure that adds terms to the accumulator.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if a term is NaN or infinite.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the resulting day's Julian day
	///     number, or an intermediate value, is not representable.
	init(_ calendar: CalendarIdentifier, accumulating body: (inout DayAccumulator) throws(DayAccumulator.Failure) -> Void) throws(CalendarError) {
		let sum: (days: Int, fractionSinceMidnight: Double)
		do throws(DayAccumulator.Failure) {
			var acc = DayAccumulator()
			try body(&acc)
			sum = try acc.flooredResult()
		} catch {
			switch error {
			case .nonFiniteValue: throw .nonFiniteValue
			case .overflow: throw .julianDayNumberNotRepresentable
			}
		}
		self.init(calendarDay: CalendarDay(julianDayNumber: sum.days, calendar), uncheckedFractionSinceMidnight: sum.fractionSinceMidnight)
	}
}

extension DayAccumulator {
	/// Adds a calendar date as a midnight-based day count: its Julian day number plus its
	/// fraction since midnight.
	///
	/// - Important: This is half a day later than adding the same instant as a
	///   ``JulianDate``, which counts from noon. Read the sum with
	///   ``CalendarDate/init(_:accumulating:)``.
	/// - Parameter date: The calendar date to add.
	/// - Throws: ``Failure/overflow`` if the sum overflows 128 bits.
	mutating func add(_ date: CalendarDate) throws(Failure) {
		var sum = self
		try sum.add(date.julianDayNumber)
		try sum.add(date.fractionSinceMidnight)
		self = sum
	}
}

extension CalendarDate {
	/// Creates a calendar date from a possibly out-of-range fraction since midnight.
	///
	/// - Note: Fractions since midnight outside the right-open interval [0, 1) carry whole days
	/// forward or backward from the specified calendar day.
	/// - Parameters:
	///   - calendarDay: The calendar day.
	///   - fractionSinceMidnight: The signed number of days, including any fraction of a day,
	///     from midnight at the start of `calendarDay`.
	/// - Returns: A calendar date with a fraction since midnight in the right-open interval [0, 1), in the
	///   calendar of `calendarDay`.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the fraction since midnight is not finite.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the resulting day's Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public static func normalized(calendarDay: CalendarDay, fractionSinceMidnight: Double) throws(CalendarError) -> CalendarDate {
		try CalendarDate(calendarDay: calendarDay, uncheckedFractionSinceMidnight: 0).adding(days: fractionSinceMidnight)
	}

	/// Creates a calendar date from possibly out-of-range month, day, and fraction since midnight values.
	///
	/// - Note: Months outside the closed interval [1, 12] roll over into earlier or later
	///   years, days are counted from the normalized month, and the fraction since midnight carries whole
	///   days. See ``JulianGregorianCalendar/julianDayNumberFromDate(_:)`` for how
	///   out-of-range values are interpreted in the Julian-Gregorian calendar.
	/// - Parameters:
	///   - year: The arithmetic year number. Year number 0 is 1 BCE.
	///   - month: The month number, possibly outside the closed interval [1, 12].
	///   - day: The day number, possibly outside the days of the month.
	///   - fractionSinceMidnight: The signed number of days, including any fraction of a day,
	///     from midnight at the start of the normalized day.
	///   - calendar: The calendar the year, month, and day belong to.
	/// - Returns: A calendar date with valid components and a fraction since midnight in the right-open
	///   interval [0, 1), in `calendar`.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the fraction since midnight is not finite.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number for the
	///     year, month, and day or the resulting day's Julian day number cannot be represented
	///     as a ``JulianDayNumber``.
	public static func normalized(year: Int, month: Int, day: Int, fractionSinceMidnight: Double, _ calendar: CalendarIdentifier) throws(CalendarError) -> CalendarDate {
		let calendarDay = try CalendarDay.normalized(year: year, month: month, day: day, calendar)
		return try normalized(calendarDay: calendarDay, fractionSinceMidnight: fractionSinceMidnight)
	}
}

extension CalendarDate {
	/// Creates a calendar date containing the specified timescale-agnostic decimal year
	/// in the given calendar.
	///
	/// - Note: The resolution of a decimal year depends on the year's magnitude.
	/// - Parameters:
	///   - decimalYear: The decimal year. Year number 0 is 1 BCE.
	///   - calendar: The calendar the decimal year is expressed in.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the decimal year is not finite.
	///   - ``CalendarError/invalidDecimalYear`` if the year cannot be represented as an `Int`.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number for the
	///     day cannot be represented as a ``JulianDayNumber``.
	public init(decimalYear: Double, _ calendar: CalendarIdentifier) throws(CalendarError) {
		let calendarDay = try CalendarDay(decimalYear: decimalYear, calendar)
		let Y = calendarDay.year
		let N = calendarDay.dayOfYear
		let d = calendarDay.numberOfDaysInYear
		let fractionSinceMidnight: Double
		if decimalYear == DecimalYearArithmetic.decimalYear(year: Y, dayOfYear: N, daysInYear: d) {
			// The start of a day is generally rounded, so measuring from the exact start would
			// leave a tiny fraction of either sign. A decimal year equal to the rounded start of
			// day is that day's midnight.
			fractionSinceMidnight = 0
		} else {
			// Measure from the start of the year rather than the start of the day. Subtracting
			// the integer year is exact because both values are multiples of the decimal year's
			// ulp and the difference is below 1.
			let yearFraction = decimalYear - Double(Y)
			// yearFraction × d − (N − 1) with a single rounding
			let fraction = Double(-(N - 1)).addingProduct(yearFraction, Double(d))
			fractionSinceMidnight = fraction > 0 ? min(fraction, Double(1).nextDown) : 0
		}
		self.init(calendarDay: calendarDay, uncheckedFractionSinceMidnight: fractionSinceMidnight)
	}

	/// The timescale-agnostic decimal year for this calendar date.
	///
	/// The fraction is the number of days elapsed since midnight on January 1, including the
	/// fraction since midnight, divided by the number of days in the year. For example, noon on
	/// January 1, 1985 is 1985 + 0.5/365 ≈ 1985.0014.
	///
	/// - Note: The resolution of a decimal year depends on the year's magnitude.
	/// - Note: This is a calendar-based value, not an astronomical epoch such as a Julian or
	///   Besselian epoch; the same instant can have slightly different decimal years in
	///   different calendars.
	public var decimalYear: Double {
		let Y = calendarDay.year
		let N = calendarDay.dayOfYear
		let d = calendarDay.numberOfDaysInYear
		return DecimalYearArithmetic.decimalYear(year: Y, dayOfYear: N, fractionSinceMidnight: fractionSinceMidnight, daysInYear: d)
	}
}

extension CalendarDate {
	/// Returns the same calendar date expressed in another calendar.
	///
	/// - Parameter other: The calendar in which to express the date.
	/// - Returns: A calendar date for the same day and time of day in `other`.
	public func convertedTo(_ other: CalendarIdentifier) -> CalendarDate {
		CalendarDate(calendarDay: calendarDay.convertedTo(other), uncheckedFractionSinceMidnight: fractionSinceMidnight)
	}

	/// Returns `true` if the specified calendar date denotes the same day and time of day,
	/// regardless of calendar.
	///
	/// - Parameter other: The calendar date to compare with.
	/// - Returns: `true` if both calendar dates have the same Julian day number and fraction since midnight;
	///   otherwise, `false`.
	public func isSameInstantAs(_ other: CalendarDate) -> Bool {
		calendarDay.isSameDayAs(other.calendarDay) && fractionSinceMidnight == other.fractionSinceMidnight
	}
}

extension CalendarDate: Comparable {
	/// Chronological order, with ties (the same instant in different calendars) broken by
	/// calendar.
	///
	/// - Returns: `true` if `lhs` is earlier than `rhs`, or if they denote the same instant and the
	///   calendar of `lhs` sorts before that of `rhs`; otherwise, `false`.
	public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
		if lhs.calendarDay.isSameDayAs(rhs.calendarDay), lhs.fractionSinceMidnight != rhs.fractionSinceMidnight {
			return lhs.fractionSinceMidnight < rhs.fractionSinceMidnight
		}
		// `CalendarDay` breaks JDN ties by calendar
		return lhs.calendarDay < rhs.calendarDay
	}
}

extension CalendarDate: CustomStringConvertible {
	/// A textual representation of the calendar date, such as `2000-1-1 +0.5 (Gregorian)`.
	public var description: String {
		"\(year)-\(month)-\(day) +\(fractionSinceMidnight) (\(calendar.name))"
	}
}

extension CalendarDate: CustomDebugStringConvertible {
	/// A textual representation of the calendar date's components, suitable for debugging.
	public var debugDescription: String {
		"CalendarDate(year: \(year), month: \(month), day: \(day), fractionSinceMidnight: \(fractionSinceMidnight), calendar: \(calendar.name))"
	}
}

extension CalendarDate: Codable {
	private enum CodingKeys: String, CodingKey {
		case year, month, day, fractionSinceMidnight, calendar
	}

	/// Creates a calendar date by decoding and validating it from the specified decoder.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: `DecodingError.dataCorrupted` if the decoded values do not form a valid
	///   calendar date, or any error thrown by `decoder`.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let year = try container.decode(Int.self, forKey: .year)
		let month = try container.decode(Int.self, forKey: .month)
		let day = try container.decode(Int.self, forKey: .day)
		let fractionSinceMidnight = try container.decode(Double.self, forKey: .fractionSinceMidnight)
		let calendar = try container.decode(CalendarIdentifier.self, forKey: .calendar)

		do throws(CalendarError) {
			self = try CalendarDate(year: year, month: month, day: day, fractionSinceMidnight: fractionSinceMidnight, calendar)
		} catch .nonFiniteValue {
			throw DecodingError.dataCorruptedError(forKey: .fractionSinceMidnight, in: container, debugDescription: "Fraction since midnight must be finite")
		} catch .invalidDayFraction {
			throw DecodingError.dataCorruptedError(forKey: .fractionSinceMidnight, in: container, debugDescription: "Fraction since midnight is outside the right-open interval [0, 1)")
		} catch .invalidDate {
			throw DecodingError.dataCorruptedError(forKey: .day, in: container, debugDescription: "year: \(year), month: \(month), day: \(day) do not form a valid \(calendar.name) date")
		} catch .julianDayNumberNotRepresentable {
			throw DecodingError.dataCorruptedError(forKey: .year, in: container, debugDescription: "The Julian day number for year: \(year), month: \(month), day: \(day) cannot be represented in the \(calendar.name) calendar")
		}
	}

	/// Encodes the calendar date's year, month, day, fraction since midnight, and calendar
	/// into the specified encoder.
	///
	/// - Parameter encoder: The encoder to write data to.
	/// - Throws: Any error thrown by `encoder`.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(year, forKey: .year)
		try container.encode(month, forKey: .month)
		try container.encode(day, forKey: .day)
		try container.encode(fractionSinceMidnight, forKey: .fractionSinceMidnight)
		try container.encode(calendar, forKey: .calendar)
	}
}
