//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The Gregorian calendar is a solar calendar with 365 days in the year
/// plus an additional leap day in certain years.
///
/// Year numbers are arithmetic and may be positive or negative. Year number 0 is 1 BCE.
///
/// Months are numbered from 1 (January) to 12 (December).
///
/// Day numbers are always positive and the first day of a month has day number 1.
public struct GregorianCalendar {
	/// The Julian day number for January 1, 1 CE in the proleptic Gregorian calendar.
	public static let epoch: JulianDayNumber = 1_721_426

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

	/// The number of days in a 400-year era, which is also the length of a block.
	private static let daysPerEra = 146_097
	/// The block containing the start of era 0 (March 1, 1 BCE in the proleptic Gregorian calendar,
	/// JDN 1,721,120 which is 306 days before `epoch`).
	private static let eraZeroBlock = 11
	/// The day within `eraZeroBlock` on which era 0 begins.
	private static let eraZeroDayOfBlock = 114_053

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

		// `era` is the March-based 400-year era containing `y`;
		// `yoe` is the year of era in [0, 400)
		let (era, yoe) = y.flooredQuotientAndRemainder(dividingBy: 400)
		// Day of era of the first day of the month, in [0, 146,069)
		let doe = yoe * 365 + yoe / 4 - yoe / 100 + (153 * mp + 2) / 5

		// `date.day` as whole 146,097-day blocks plus remaining days in [0, 146,097)
		let (dayBlocks, dayRem) = date.day.flooredQuotientAndRemainder(dividingBy: daysPerEra)

		// The JDN of March 1, 0 in the proleptic Gregorian calendar is 1,721,120:
		//   1,721,120 = 11 × 146,097 + 114,053

		// J = (era + 11 + dayBlocks) × 146,097 + (doe + dayRem - 1 + 114,053)
		// The second term is in [114,052, 406,217); move its whole blocks into the first.
		let (carry, r) = (doe + dayRem - 1 + eraZeroDayOfBlock).quotientAndRemainder(dividingBy: daysPerEra)
		// `q` and `r` are the floored quotient and remainder of the JDN divided by 146,097
		let q = era + eraZeroBlock + dayBlocks + carry

		// Compute q × 146,097 + r. For negative q, use (q + 1) × 146,097 + (r - 146,097) so
		// the product can't overflow when the result fits.
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
		// `q` and `r` are the floored quotient and remainder of the JDN divided by 146,097
		let (q, r) = J.flooredQuotientAndRemainder(dividingBy: daysPerEra)

		// Subtract 1,721,120 = 11 × 146,097 + 114,053, borrowing a block when r < 114,053.
		// `era` is the March-based 400-year era; `doe` is the day of era in [0, 146,097)
		let (era, doe) = r >= eraZeroDayOfBlock ? (q - eraZeroBlock, r - eraZeroDayOfBlock) : (q - eraZeroBlock - 1, r - eraZeroDayOfBlock + daysPerEra)

		// Year of era in [0, 400)
		let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
		// Day of year in [0, 366) with March 1 = 0
		let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
		// Month in [0, 12) with March = 0
		let mp = (5 * doy + 2) / 153

		let day = doy - (153 * mp + 2) / 5 + 1
		let month = mp < 10 ? mp + 3 : mp - 9
		let year = era * 400 + yoe + (month <= 2 ? 1 : 0)

		return (year, month, day)
	}
}

extension GregorianCalendar {
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

extension GregorianCalendar {
	/// The Julian day number for October 15, 1582 in the Gregorian calendar.
	static let papalReform: JulianDayNumber = 2_299_161

	/// Returns `true` if the specified Julian day number is less than 2,299,161
	/// (October 15, 1582 in the Gregorian calendar).
	public static func beforePapalReform(_ J: JulianDayNumber) -> Bool {
		J < papalReform
	}
}

extension GregorianCalendar {
	/// Returns `true` if the specified year is a leap year.
	public static func isLeapYear(_ Y: Int) -> Bool {
		Y % 4 == 0 && (Y % 100 != 0 || Y % 400 == 0)
	}
}

extension GregorianCalendar {
	/// The number of months in one year.
	public static let numberOfMonthsInYear = JulianCalendar.numberOfMonthsInYear

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

extension GregorianCalendar {
	/// Returns `true` if the specified year, month, and day form a valid date.
	public static func isValid(year Y: Int, month M: Int, day D: Int) -> Bool {
		isValidDate((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
	public static func isValidDate(_ date: YearMonthDay) -> Bool {
		guard let daysInMonth = try? numberOfDaysIn(month: date.month, year: date.year) else {
			return false
		}
		return date.day >= 1 && date.day <= daysInMonth
	}
}

extension GregorianCalendar {
	/// Returns the day of the week from 1 (Sunday) to 7 (Saturday)
	/// for the specified Julian day number.
	public static func dayOfWeek(_ J: JulianDayNumber) -> Int {
		JulianCalendar.dayOfWeek(J)
	}
}

extension GregorianCalendar {
	/// Returns the ordinal day (day of year) for the specified year, month, and day.
	///
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func ordinalDayFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Int {
		try julianDayNumberFrom(year: Y, month: M, day: D) - julianDayNumberFrom(year: Y, month: 1, day: 1) + 1
	}

	/// Returns the year, month, and day for the specified year and ordinal day.
	///
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func dateFrom(year Y: Int, ordinalDay N: Int) throws(CalendarError) -> YearMonthDay {
		try dateFromJulianDayNumber(julianDayNumberFrom(year: Y, month: 1, day: 1) + N - 1)
	}
}

extension GregorianCalendar {
	/// Returns the month and day of Easter in the specified year.
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
