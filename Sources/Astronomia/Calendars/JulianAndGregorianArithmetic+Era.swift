//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

// Based on https://howardhinnant.github.io/date_algorithms.html

extension JulianAndGregorianArithmetic {
	/// Returns the year and month of the specified date with years beginning on March 1.
	///
	/// Starting the year in March puts the leap day at the end of the year, so the day of
	/// year of the first of each month doesn't depend on the leap year rule.
	///
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The normalized March-based year and month in the right-open interval [0, 12),
	///   with March = 0.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the normalized year
	///   cannot be represented as an `Int`.
	static func marchBasedYearAndMonth(_ date: YearMonthDay) throws(CalendarError) -> (year: Int, month: Int) {
		// Normalize the month in two steps so no intermediate value can overflow.
		// `m0` is the month in [0, 12) with January = 0;
		// `mp` is the month in [0, 12) with March = 0.
		let (yc0, m0) = date.month.flooredQuotientAndRemainder(dividingBy: 12)
		let (yc1, mp) = (m0 - 3).flooredQuotientAndRemainder(dividingBy: 12)

		let (y, yearOverflow) = date.year.addingReportingOverflow(yc0 + yc1)
		guard !yearOverflow else { throw .julianDayNumberNotRepresentable }

		return (y, mp)
	}
}

extension JulianAndGregorianArithmetic {
	/// The repeating cycle of years, or era, of a calendar, positioned against the Julian
	/// day numbers.
	///
	/// An era begins on March 1 and spans a whole number of years and days: 4 years and 1,461
	/// days in the Julian calendar, and 400 years and 146,097 days in the Gregorian calendar.
	/// Julian day numbers are split into blocks of the same length, and era 0, which begins on
	/// March 1, 1 BCE, starts on day ``zeroDayOfBlock`` of block ``zeroBlock``.
	struct EraLayout {
		/// The number of years in an era.
		let years: Int
		/// The number of days in an era, which is also the length of a block.
		let days: Int
		/// The block containing the start of era 0.
		let zeroBlock: Int
		/// The day within the block containing the start of era 0 on which era 0 begins,
		/// in the right-open interval [1, `days`).
		let zeroDayOfBlock: Int
	}
}

extension JulianAndGregorianArithmetic.EraLayout {
	/// Returns the era containing the specified March-based year and the year of era.
	///
	/// - Parameter y: The March-based year.
	/// - Returns: The era and the year of era in the right-open interval [0, ``years``).
	func eraAndYearOfEra(marchBasedYear y: Int) -> (era: Int, yearOfEra: Int) {
		let (era, yoe) = y.flooredQuotientAndRemainder(dividingBy: years)
		return (era, yoe)
	}

	/// Returns the Julian day number for the specified day of the month starting on a
	/// day of era.
	///
	/// - Parameters:
	///   - era: The era.
	///   - doe: The day of era of the first day of the month, in the right-open
	///     interval [0, ``days``).
	///   - day: The day number of the month, possibly out of range.
	/// - Returns: The Julian day number.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   cannot be represented as a ``JulianDayNumber``.
	func julianDayNumber(era: Int, dayOfEra doe: Int, day: Int) throws(CalendarError) -> JulianDayNumber {
		// `day` as whole blocks plus remaining days in [0, days)
		let (dayBlocks, dayRem) = day.flooredQuotientAndRemainder(dividingBy: days)

		// J = (era + zeroBlock + dayBlocks) × days + (doe + dayRem - 1 + zeroDayOfBlock)
		// The second term is in [zeroDayOfBlock - 1, 3 × days), so it is non-negative and
		// truncating division is floored; move its whole blocks into the first.
		let (carry, r) = (doe + dayRem - 1 + zeroDayOfBlock).quotientAndRemainder(dividingBy: days)
		// `q` and `r` are the floored quotient and remainder of the JDN divided by `days`
		let q = era + zeroBlock + dayBlocks + carry

		// Compute q × days + r. For negative q, use (q + 1) × days + (r - days) so the
		// product can't overflow when the result fits.
		let (blocks, remainder) = q >= 0 ? (q, r) : (q + 1, r - days)

		let (product, multiplyOverflow) = blocks.multipliedReportingOverflow(by: days)
		guard !multiplyOverflow else { throw .julianDayNumberNotRepresentable }

		let (result, addOverflow) = product.addingReportingOverflow(remainder)
		guard !addOverflow else { throw .julianDayNumberNotRepresentable }

		return result
	}
}

extension JulianAndGregorianArithmetic.EraLayout {
	/// Returns the era containing the specified Julian day number and the day of era.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The era and the day of era in the right-open interval [0, ``days``).
	func eraAndDayOfEra(julianDayNumber J: JulianDayNumber) -> (era: Int, dayOfEra: Int) {
		// `q` and `r` are the floored quotient and remainder of the JDN divided by `days`
		let (q, r) = J.flooredQuotientAndRemainder(dividingBy: days)

		// Subtract zeroBlock × days + zeroDayOfBlock, borrowing a block when r < zeroDayOfBlock
		return r >= zeroDayOfBlock ? (q - zeroBlock, r - zeroDayOfBlock) : (q - zeroBlock - 1, r - zeroDayOfBlock + days)
	}

	/// Returns the year, month, and day for the specified day of a March-based year.
	///
	/// - Parameters:
	///   - era: The era.
	///   - yoe: The year of era in the right-open interval [0, ``years``).
	///   - doy: The day of the March-based year in the right-open interval [0, 366)
	///     with March 1 = 0.
	/// - Returns: The year, month, and day.
	func date(era: Int, yearOfEra yoe: Int, dayOfYear doy: Int) -> YearMonthDay {
		// Month in [0, 12) with March = 0
		let mp = (5 * doy + 2) / 153

		let day = doy - (153 * mp + 2) / 5 + 1
		let month = mp < 10 ? mp + 3 : mp - 9
		let year = era * years + yoe + (month <= 2 ? 1 : 0)

		return (year, month, day)
	}
}
