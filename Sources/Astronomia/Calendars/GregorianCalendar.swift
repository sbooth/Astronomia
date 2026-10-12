//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

private typealias Arithmetic = JulianAndGregorianArithmetic

/// The Gregorian calendar is a solar calendar with 365 days in the year
/// plus an additional leap day in years divisible by 4, except for years divisible by 100
/// but not by 400.
///
/// The calendar's rules are also applied to dates before its introduction on October 15,
/// 1582, so it is proleptic for those dates.
///
/// Year numbers are arithmetic and may be positive or negative. Year number 0 is 1 BCE.
///
/// Months are numbered from 1 (January) to 12 (December).
///
/// Day numbers are always positive and the first day of a month has day number 1.
public enum GregorianCalendar {
	/// The Julian day number for January 1, 1 CE in the proleptic Gregorian calendar.
	public static let epoch: JulianDayNumber = 1_721_426

	/// Returns the Julian day number for the specified year, month, and day.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number, possibly outside the closed interval [1, 12].
	///   - D: The day number, possibly outside the days of the month.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> JulianDayNumber {
		try julianDayNumberFromDate((Y, M, D))
	}

	/// The 400-year cycle of the Gregorian calendar, positioned against the Julian day numbers.
	///
	/// The Gregorian leap year rule repeats every 400 years, and those 400 years always contain
	/// 146,097 days (97 leap years). Each era begins on March 1, so its leap day, if any, falls
	/// at the end of a year. Era 0 begins on March 1, 1 BCE (year 0), which is JDN 1,721,120.
	///
	/// Julian day numbers are divided into blocks of 146,097 days counted from JDN 0, which is
	/// November 24, 4714 BCE in the proleptic Gregorian calendar. Because a block is exactly one
	/// 400-year cycle, every block begins on November 24, and block `k` begins in year
	/// −4713 + 400 × `k`.
	private enum Era: Arithmetic.EraLayout {
		/// The number of years in one cycle of the Gregorian leap year rule.
		static var years: Int { 400 }

		/// The number of days in 400 Gregorian years: 400 × 365 + 97 leap days.
		///
		/// This is also the length of a block of Julian day numbers.
		static var days: Int { 146_097 }

		/// The block of Julian day numbers containing March 1, 1 BCE.
		///
		/// Block 11 spans JDN 1,607,067 (November 24, 314 BCE) through JDN 1,753,163.
		static var zeroBlock: Int { 11 }

		/// The day within block 11 on which era 0 begins.
		///
		/// Era 0 begins at JDN 11 × 146,097 + 114,053 = 1,721,120, which is March 1, 1 BCE,
		/// 114,053 days after the start of the block on November 24, 314 BCE.
		static var zeroDayOfBlock: Int { 114_053 }
	}

	/// Returns the Julian day number for the specified date.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFromDate(_ date: YearMonthDay) throws(CalendarError) -> JulianDayNumber {
		let (y, mp) = try Arithmetic.marchBasedYearAndMonth(date)
		let (era, yoe) = Era.eraAndYearOfEra(marchBasedYear: y)
		// Day of era of the first day of the month, in [0, 146,069)
		let doe = yoe * 365 + yoe / 4 - yoe / 100 + (153 * mp + 2) / 5
		return try Era.julianDayNumber(era: era, dayOfEra: doe, day: date.day)
	}

	/// Returns the year, month, and day for the specified Julian day number.
	///
	/// - Note: Every ``JulianDayNumber`` value is a valid Julian day number.
	/// - Parameter J: The Julian day number.
	/// - Returns: A valid date in the Gregorian calendar.
	public static func dateFromJulianDayNumber(_ J: JulianDayNumber) -> YearMonthDay {
		let (era, doe) = Era.eraAndDayOfEra(julianDayNumber: J)
		// Year of era in [0, 400)
		let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
		// Day of year in [0, 366) with March 1 = 0
		let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
		return Era.date(era: era, yearOfEra: yoe, dayOfYear: doy)
	}
}

extension GregorianCalendar {
	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number, possibly outside the closed interval [1, 12].
	///   - D: The day number, possibly outside the days of the month.
	/// - Returns: The equivalent valid date in the Gregorian calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func normalizedDateFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> YearMonthDay {
		try normalizedDate((Y, M, D))
	}

	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The equivalent valid date in the Gregorian calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func normalizedDate(_ date: YearMonthDay) throws(CalendarError) -> YearMonthDay {
		try dateFromJulianDayNumber(julianDayNumberFromDate(date))
	}
}

extension GregorianCalendar {
	/// The Julian day number for October 15, 1582 in the Gregorian calendar.
	static let papalReform: JulianDayNumber = 2_299_161

	/// Returns `true` if the specified Julian day number is less than 2,299,161
	/// (October 15, 1582 in the Gregorian calendar), the day the Gregorian calendar took effect.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: `true` if `J` is before October 15, 1582 in the Gregorian calendar; otherwise,
	///   `false`.
	public static func beforePapalReform(_ J: JulianDayNumber) -> Bool {
		J < papalReform
	}
}

extension GregorianCalendar {
	/// Returns `true` if the specified year is a leap year.
	///
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: `true` if `Y` is a leap year in the Gregorian calendar; otherwise, `false`.
	public static func isLeapYear(_ Y: Int) -> Bool {
		Y % 4 == 0 && (Y % 100 != 0 || Y % 400 == 0)
	}
}

extension GregorianCalendar {
	/// The number of months in one year.
	public static let numberOfMonthsInYear = JulianCalendar.numberOfMonthsInYear

	/// Returns the number of days in the specified year.
	///
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The number of days in year `Y`: 365 or 366.
	public static func numberOfDaysInYear(_ Y: Int) -> Int {
		Arithmetic.numberOfDays(isLeap: isLeapYear(Y))
	}

	/// Returns the number of days in the specified month and year.
	///
	/// - Parameters:
	///   - M: The month number from 1 (January) to 12 (December).
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The number of days in the month, from 28 to 31.
	/// - Throws: ``CalendarError/invalidDate`` if the month is outside the closed interval [1, 12].
	public static func numberOfDaysIn(month M: Int, year Y: Int) throws(CalendarError) -> Int {
		try Arithmetic.numberOfDaysIn(month: M, isLeap: isLeapYear(Y))
	}
}

extension GregorianCalendar {
	/// Returns `true` if the specified year, month, and day form a valid date.
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number.
	///   - D: The day number.
	/// - Returns: `true` if the year, month, and day form a valid date in the Gregorian calendar;
	///   otherwise, `false`.
	public static func isValid(year Y: Int, month M: Int, day D: Int) -> Bool {
		isValidDate((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
	///
	/// - Parameter date: The year, month, and day to check.
	/// - Returns: `true` if `date` is a valid date in the Gregorian calendar; otherwise, `false`.
	public static func isValidDate(_ date: YearMonthDay) -> Bool {
		Arithmetic.isValid(month: date.month, day: date.day, isLeap: isLeapYear(date.year))
	}
}

extension GregorianCalendar {
	/// Returns the day of the week from 1 (Sunday) to 7 (Saturday)
	/// for the specified Julian day number.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The day of the week from 1 (Sunday) to 7 (Saturday).
	public static func dayOfWeek(_ J: JulianDayNumber) -> Int {
		Arithmetic.dayOfWeek(J)
	}
}


extension GregorianCalendar {
	/// Returns the day of year (ordinal day) for the specified Julian day number, starting at 1.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The day of year, from 1 to the number of days in the year.
	public static func dayOfYearFromJulianDayNumber(_ J: JulianDayNumber) -> Int {
		let (Y, M, D) = dateFromJulianDayNumber(J)
		return Arithmetic.dayOfYear(month: M, day: D, isLeap: isLeapYear(Y))
	}

	/// Returns the day of year (ordinal day) for the specified year, month, and day,
	/// starting at 1.
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number from 1 (January) to 12 (December).
	///   - D: The day number, starting at 1.
	/// - Returns: The day of year, from 1 to the number of days in the year.
	/// - Throws: ``CalendarError/invalidDate`` if the year, month, and day do not form
	///   a valid date.
	public static func dayOfYearFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Int {
		guard isValid(year: Y, month: M, day: D) else { throw .invalidDate }
		return Arithmetic.dayOfYear(month: M, day: D, isLeap: isLeapYear(Y))
	}

	/// Returns the year, month, and day for the specified year and day of year (ordinal day).
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - N: The day of year, starting at 1.
	/// - Returns: The year, month, and day in the Gregorian calendar.
	/// - Throws: ``CalendarError/invalidDate`` if the year and day of year do not form
	///   a valid date.
	public static func dateFrom(year Y: Int, dayOfYear N: Int) throws(CalendarError) -> YearMonthDay {
		guard N >= 1, N <= numberOfDaysInYear(Y) else { throw .invalidDate }
		let (M, D) = Arithmetic.monthAndDay(dayOfYear: N, isLeap: isLeapYear(Y))
		return (Y, M, D)
	}
}

extension GregorianCalendar {
	/// Returns the decimal year for the start of the day with the specified Julian day number.
	///
	/// The fraction is the number of whole days elapsed since January 1 divided by the number
	/// of days in the year, so January 1, 1985 is 1985.0 and July 2, 1985 is
	/// 1985 + 182/365 ≈ 1985.4986.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Note: This is a calendar-based value, not an astronomical epoch such as a Julian or
	///   Besselian epoch.
	/// - Parameter J: The Julian day number.
	/// - Returns: The decimal year for the start of the day in the Gregorian calendar.
	public static func decimalYearFromJulianDayNumber(_ J: JulianDayNumber) -> Double {
		let (Y, M, D) = dateFromJulianDayNumber(J)
		let N = Arithmetic.dayOfYear(month: M, day: D, isLeap: isLeapYear(Y))
		let d = numberOfDaysInYear(Y)
		return DecimalYearArithmetic.decimalYear(year: Y, dayOfYear: N, daysInYear: d)
	}

	/// Returns the Julian day number of the day containing the specified decimal year.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Parameter decimalYear: The decimal year. Year number 0 is 1 BCE.
	/// - Returns: The Julian day number of the day containing `decimalYear`.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the decimal year is not finite.
	///   - ``CalendarError/invalidDecimalYear`` if the year cannot be represented as an `Int`.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number for the
	///     day cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFromDecimalYear(_ decimalYear: Double) throws(CalendarError) -> JulianDayNumber {
		try julianDayNumberFromDate(dateFromDecimalYear(decimalYear))
	}

	/// Returns the decimal year for the start of the specified year, month, and day.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number from 1 (January) to 12 (December).
	///   - D: The day number, starting at 1.
	/// - Returns: The decimal year for the start of the day in the Gregorian calendar.
	/// - Throws: ``CalendarError/invalidDate`` if the year, month, and day do not form
	///   a valid date.
	public static func decimalYearFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Double {
		let N = try dayOfYearFrom(year: Y, month: M, day: D)
		let d = numberOfDaysInYear(Y)
		return DecimalYearArithmetic.decimalYear(year: Y, dayOfYear: N, daysInYear: d)
	}

	/// Returns the year, month, and day containing the specified decimal year.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Parameter decimalYear: The decimal year. Year number 0 is 1 BCE.
	/// - Returns: The year, month, and day in the Gregorian calendar.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the decimal year is not finite.
	///   - ``CalendarError/invalidDecimalYear`` if the year cannot be represented as an `Int`.
	public static func dateFromDecimalYear(_ decimalYear: Double) throws(CalendarError) -> YearMonthDay {
		let (Y, N) = try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: decimalYear, daysInYear: numberOfDaysInYear)
		let (M, D) = Arithmetic.monthAndDay(dayOfYear: N, isLeap: isLeapYear(Y))
		return (Y, M, D)
	}
}

extension GregorianCalendar {
	/// Returns the month and day of Easter in the specified year.
	///
	/// Uses the Gregorian computus for every year, including years before 1583. Gregorian
	/// Easter dates repeat every 5,700,000 years, so any year number is accepted.
	///
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The month (3 or 4) and day of Easter Sunday in the Gregorian calendar.
	public static func easter(year Y: Int) -> (month: Int, day: Int) {
		let Y = Y.flooredRemainder(dividingBy: 5_700_000)
		// Based on the algorithm from the Explanatory Supplement to the Astronomical Almanac,
		// 3rd edition, S.E. Urban and P.K. Seidelmann eds.,
		// (Mill Valley, CA: University Science Books), Chapter 15, pp. 585-624.
		let a = Y / 100
		let b = a - a / 4
		let c = Y % 19
		let e = (15 + 19 * c + b - (a - (a + 8) / 25 + 1) / 3) % 30
		let f = e - (c + 11 * e) / 319
		let g = 22 + f + (4 - Y - Y / 4 + b - f).flooredRemainder(dividingBy: 7)
		let M = 3 + g / 32
		let D = 1 + ((g - 1) % 31)
		return (M, D)
	}
}
