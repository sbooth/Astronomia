//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The Julian calendar is a solar calendar with 365 days in the year
/// plus an additional leap day every fourth year.
///
/// Year numbers are arithmetic and may be positive or negative. Year number 0 is 1 BCE.
///
/// Months are numbered from 1 (January) to 12 (December).
///
/// Day numbers are always positive and the first day of a month has day number 1.
public struct JulianCalendar {
	/// The Julian day number for January 1, 1 CE in the Julian calendar.
	public static let epoch: JulianDayNumber = 1_721_424

	/// Returns the Julian day number for the specified year, month, and day.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years. Out-of-range
	///   days are counted forward or backward from the normalized year and month.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> JulianDayNumber {
		try julianDayNumberFromDate((Y, M, D))
	}

	// Based on https://howardhinnant.github.io/date_algorithms.html

	/// The number of days in a 4-year era, which is also the length of a block.
	private static let daysPerEra = 1_461
	/// The block containing the start of era 0 (March 1, 1 BCE in the Julian calendar,
	/// JDN 1,721,118 which is 306 days before `epoch`).
	private static let eraZeroBlock = 1_178
	/// The day within `eraZeroBlock` on which era 0 begins.
	private static let eraZeroDayOfBlock = 60

	/// Returns the Julian day number for the specified date.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years. Out-of-range
	///   days are counted forward or backward from the normalized year and month.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFromDate(_ date: YearMonthDay) throws(CalendarError) -> JulianDayNumber {
		// Normalize the month in two steps so no intermediate value can overflow.
		// `m0` is the month in [0, 12) with January = 0;
		// `mp` is the month in [0, 12) with March = 0.
		let (yc0, m0) = date.month.flooredQuotientAndRemainder(dividingBy: 12)
		let (yc1, mp) = (m0 - 3).flooredQuotientAndRemainder(dividingBy: 12)

		// The normalized year, with years beginning on March 1
		let (y, yearOverflow) = date.year.addingReportingOverflow(yc0 + yc1)
		guard !yearOverflow else { throw .julianDayNumberNotRepresentable }

		// `era` is the March-based 4-year era containing `y`; `yoe` is the year of era in [0, 4)
		let (era, yoe) = y.flooredQuotientAndRemainder(dividingBy: 4)
		// Day of era of the first day of the month, in [0, 1,433)
		let doe = yoe * 365 + (153 * mp + 2) / 5

		// `date.day` as whole 1,461-day blocks plus remaining days in [0, 1,461)
		let (dayBlocks, dayRem) = date.day.flooredQuotientAndRemainder(dividingBy: daysPerEra)

		// The JDN of March 1, 0 in the Julian calendar is 1,721,118:
		//   1,721,118 = 1,178 × 1,461 + 60

		// J = (era + 1,178 + dayBlocks) × 1,461 + (doe + dayRem - 1 + 60)
		// The second term is in [59, 2,952); move its whole blocks into the first.
		let (carry, r) = (doe + dayRem - 1 + eraZeroDayOfBlock).quotientAndRemainder(dividingBy: daysPerEra)
		// `q` and `r` are the floored quotient and remainder of the JDN divided by 1,461
		let q = era + eraZeroBlock + dayBlocks + carry

		// Compute q × 1,461 + r. For negative q, use (q + 1) × 1,461 + (r - 1,461) so the product
		// can't overflow when the result fits.
		let (blocks, days) = q >= 0 ? (q, r) : (q + 1, r - daysPerEra)

		let (product, multiplyOverflow) = blocks.multipliedReportingOverflow(by: daysPerEra)
		guard !multiplyOverflow else { throw .julianDayNumberNotRepresentable }

		let (result, addOverflow) = product.addingReportingOverflow(days)
		guard !addOverflow else { throw .julianDayNumberNotRepresentable }

		return result
	}

	/// Returns the year, month, and day for the specified Julian day number.
	///
	/// - Note: Every ``JulianDayNumber`` value is a valid Julian day number.
	public static func dateFromJulianDayNumber(_ J: JulianDayNumber) -> YearMonthDay {
		// `q` and `r` are the floored quotient and remainder of the JDN divided by 1,461
		let (q, r) = J.flooredQuotientAndRemainder(dividingBy: daysPerEra)

		// Subtract 1,721,118 = 1,178 × 1,461 + 60, borrowing a block when r < 60.
		// `era` is the March-based 4-year era; `doe` is the day of era in [0, 1,461)
		let (era, doe) = r >= eraZeroDayOfBlock ? (q - eraZeroBlock, r - eraZeroDayOfBlock) : (q - eraZeroBlock - 1, r - eraZeroDayOfBlock + daysPerEra)

		// Year of era in [0, 4)
		let yoe = (doe - doe / 1_460) / 365
		// Day of year in [0, 366) with March 1 = 0
		let doy = doe - 365 * yoe
		// Month in [0, 12) with March = 0
		let mp = (5 * doy + 2) / 153

		let day = doy - (153 * mp + 2) / 5 + 1
		let month = mp < 10 ? mp + 3 : mp - 9
		let year = era * 4 + yoe + (month <= 2 ? 1 : 0)

		return (year, month, day)
	}
}

extension JulianCalendar {
	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years. Out-of-range
	///   days are counted forward or backward from the normalized year and month.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func normalizedDateFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> YearMonthDay {
		try normalizedDate((Y, M, D))
	}

	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years. Out-of-range
	///   days are counted forward or backward from the normalized year and month.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func normalizedDate(_ date: YearMonthDay) throws(CalendarError) -> YearMonthDay {
		try dateFromJulianDayNumber(julianDayNumberFromDate(date))
	}
}

extension JulianCalendar {
	/// The Julian day number for January 1, 45 BCE in the Julian calendar.
	static let effective: JulianDayNumber = 1_704_987

	/// Returns `true` if the specified Julian day number is less than 1,704,987
	/// (January 1, 45 BCE in the Julian calendar).
	public static func isProleptic(_ J: JulianDayNumber) -> Bool {
		J < effective
	}
}

extension JulianCalendar {
	/// Returns `true` if the specified year is a leap year.
	public static func isLeapYear(_ Y: Int) -> Bool {
		Y % 4 == 0
	}
}

extension JulianCalendar {
	/// The number of months in one year.
	public static let numberOfMonthsInYear = 12

	/// Returns the number of days in the specified year.
	public static func numberOfDaysInYear(_ Y: Int) -> Int {
		isLeapYear(Y) ? 366 : 365
	}

	/// Returns the number of days in the specified month and year.
	///
	/// - Throws: ``CalendarError/invalidDate`` if the month is not valid.
	public static func numberOfDaysIn(month M: Int, year Y: Int) throws(CalendarError) -> Int {
		switch M {
		case 4, 6, 9, 11:
			return 30
		case 2:
			return isLeapYear(Y) ? 29 : 28
		case 1, 3, 5, 7, 8, 10, 12:
			return 31
		default:
			throw .invalidDate
		}
	}
}

extension JulianCalendar {
	/// Returns `true` if the specified year, month, and day form a valid date.
	public static func isValid(year Y: Int, month M: Int, day D: Int) -> Bool {
		isValidDate((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
	public static func isValidDate(_ date: YearMonthDay) -> Bool {
		guard let daysInMonth = try? numberOfDaysIn(month: date.month, year: date.year) else { return false }
		return date.day >= 1 && date.day <= daysInMonth
	}
}

extension JulianCalendar {
	/// Returns the day of the week from 1 (Sunday) to 7 (Saturday)
	/// for the specified Julian day number.
	public static func dayOfWeek(_ J: JulianDayNumber) -> Int {
		1 + ((J % 7) + 8) % 7
	}
}

extension JulianCalendar {
	/// Returns the day of year (ordinal day) for the specified Julian day number, starting at 1.
	public static func dayOfYearFromJulianDayNumber(_ J: JulianDayNumber) -> Int {
		let (Y, M, D) = dateFromJulianDayNumber(J)
		return dayOfYearFrom(uncheckedYear: Y, month: M, day: D)
	}

	/// Returns the day of year (ordinal day) for the specified year, month, and day, starting at 1.
	///
	/// - Throws: ``CalendarError/invalidDate`` if the year, month, and day do not form
	///   a valid date.
	public static func dayOfYearFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Int {
		guard isValid(year: Y, month: M, day: D) else { throw .invalidDate }
		return dayOfYearFrom(uncheckedYear: Y, month: M, day: D)
	}

	/// The number of days before the first of the month in a common year, indexed from 0 (January) to 11 (December).
	static let daysBeforeCommonYearMonth = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	/// The number of days before the first of the month in a leap year, indexed from 0 (January) to 11 (December).
	static let daysBeforeLeapYearMonth = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

	/// Returns the day of year (ordinal day) for the specified year, month, and day, starting at 1.
	private static func dayOfYearFrom(uncheckedYear Y: Int, month M: Int, day D: Int) -> Int {
		let daysBeforeMonth = isLeapYear(Y) ? daysBeforeLeapYearMonth : daysBeforeCommonYearMonth
		return D + daysBeforeMonth[M - 1]
	}

	/// Returns the year, month, and day for the specified year and day of year (ordinal day).
	///
	/// - Throws: ``CalendarError/invalidDate`` if the year and day of year do not form
	///   a valid date.
	public static func dateFrom(year Y: Int, dayOfYear N: Int) throws(CalendarError) -> YearMonthDay {
		guard N >= 1, N <= numberOfDaysInYear(Y) else { throw .invalidDate }
		let daysBeforeMonth = isLeapYear(Y) ? daysBeforeLeapYearMonth : daysBeforeCommonYearMonth
		let m = daysBeforeMonth.lastIndex { $0 < N }!
		return (Y, m + 1, N - daysBeforeMonth[m])
	}
}

extension JulianCalendar {
	/// Returns the month and day of Easter in the specified year.
	public static func easter(year Y: Int) -> (month: Int, day: Int) {
		let Y = Y.flooredRemainder(dividingBy: 532)
		// Algorithm from the Explanatory Supplement to the Astronomical Almanac, 3rd edition,
		// S.E. Urban and P.K. Seidelmann eds., (Mill Valley, CA: University Science Books),
		// Chapter 15, pp. 585-624.
		let a = 22 + ((225 - 11 * (Y % 19)) % 30)
		let g = a + ((56 + 6 * Y - Y / 4 - a) % 7)
		let M = 3 + g / 32
		let D = 1 + ((g - 1) % 31)
		return (M, D)
	}
}
