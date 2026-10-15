//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct CalendarDateTests {
	// MARK: - Creation

	@Test func initFromComponents() throws {
		let date = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .gregorian)
		#expect(date.year == 2000)
		#expect(date.month == 1)
		#expect(date.day == 1)
		#expect(date.fractionSinceMidnight == 0.25)
		#expect(date.calendar == .gregorian)
		#expect(date.julianDayNumber == 2_451_545)
		#expect(date.calendarDay == (try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)))

		let midnight = try CalendarDate(year: 1582, month: 10, day: 15, .julianGregorian)
		#expect(midnight.fractionSinceMidnight == 0)
		#expect(midnight.julianDayNumber == 2_299_161)
	}

	@Test func initFromCalendarDay() throws {
		let day = try CalendarDay(year: 1999, month: 12, day: 19, .julian)
		let date = try CalendarDate(calendarDay: day, fractionSinceMidnight: 0.75)
		#expect(date.calendarDay == day)
		#expect(date.fractionSinceMidnight == 0.75)
		#expect(date == (try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.75, .julian)))
	}

	@Test func fractionSinceMidnightValidation() throws {
		let day = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		#expect(try CalendarDate(calendarDay: day, fractionSinceMidnight: 0).fractionSinceMidnight == 0)
		#expect(try CalendarDate(calendarDay: day, fractionSinceMidnight: Double(1).nextDown).fractionSinceMidnight == Double(1).nextDown)
		#expect(try CalendarDate(calendarDay: day, fractionSinceMidnight: .leastNonzeroMagnitude).fractionSinceMidnight == .leastNonzeroMagnitude)

		#expect(throws: CalendarError.invalidDayFraction) { try CalendarDate(calendarDay: day, fractionSinceMidnight: 1) }
		#expect(throws: CalendarError.invalidDayFraction) { try CalendarDate(calendarDay: day, fractionSinceMidnight: 1.5) }
		#expect(throws: CalendarError.invalidDayFraction) { try CalendarDate(calendarDay: day, fractionSinceMidnight: -0.25) }
		#expect(throws: CalendarError.invalidDayFraction) { try CalendarDate(calendarDay: day, fractionSinceMidnight: -.leastNonzeroMagnitude) }
		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate(calendarDay: day, fractionSinceMidnight: .nan) }
		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate(calendarDay: day, fractionSinceMidnight: .infinity) }
		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate(calendarDay: day, fractionSinceMidnight: -.infinity) }
	}

	@Test func negativeZeroFractionIsStoredAsPositiveZero() throws {
		let day = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		let date = try CalendarDate(calendarDay: day, fractionSinceMidnight: -0.0)
		#expect(date.fractionSinceMidnight == 0)
		#expect(date.fractionSinceMidnight.sign == .plus)
		#expect(date == (try CalendarDate(calendarDay: day, fractionSinceMidnight: 0)))
		#expect(date.hashValue == (try CalendarDate(calendarDay: day, fractionSinceMidnight: 0)).hashValue)
	}

	@Test func initFromInvalidComponentsThrows() {
		#expect(throws: CalendarError.invalidDate) { try CalendarDate(year: 2001, month: 2, day: 29, .gregorian) }
		#expect(throws: CalendarError.invalidDate) { try CalendarDate(year: 1582, month: 10, day: 10, .julianGregorian) }
		#expect(throws: CalendarError.invalidDate) { try CalendarDate(year: 2000, month: 13, day: 1, fractionSinceMidnight: 0.5, .julian) }
		// The date is validated before the fraction since midnight
		#expect(throws: CalendarError.invalidDate) { try CalendarDate(year: 2001, month: 2, day: 29, fractionSinceMidnight: 2, .gregorian) }
		#expect(throws: CalendarError.invalidDayFraction) { try CalendarDate(year: 2000, month: 2, day: 29, fractionSinceMidnight: 2, .gregorian) }
		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate(year: 2000, month: 2, day: 29, fractionSinceMidnight: .nan, .gregorian) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDate(year: .max, month: 1, day: 1, .julian) }
	}

	// MARK: - Arithmetic

	@Test func addingWholeAndFractionalDays() throws {
		let date = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.75, .gregorian)
		#expect(try date.adding(days: 0) == date)
		#expect(try date.adding(days: 1) == CalendarDate(year: 2000, month: 1, day: 2, fractionSinceMidnight: 0.75, .gregorian))
		#expect(try date.adding(days: -1) == CalendarDate(year: 1999, month: 12, day: 31, fractionSinceMidnight: 0.75, .gregorian))
		#expect(try date.adding(days: 1, fractionalDay: 0.5) == CalendarDate(year: 2000, month: 1, day: 3, fractionSinceMidnight: 0.25, .gregorian))
		#expect(try date.adding(days: -1, fractionalDay: 0.5) == CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .gregorian))
		#expect(try date.adding(days: 0, fractionalDay: 0.25) == CalendarDate(year: 2000, month: 1, day: 2, .gregorian))
		#expect(try date.adding(days: 60) == CalendarDate(year: 2000, month: 3, day: 1, fractionSinceMidnight: 0.75, .gregorian))

		#expect(throws: CalendarError.invalidDayFraction) { try date.adding(days: 1, fractionalDay: 1) }
		#expect(throws: CalendarError.invalidDayFraction) { try date.adding(days: 1, fractionalDay: -0.5) }
		#expect(throws: CalendarError.nonFiniteValue) { try date.adding(days: 1, fractionalDay: .nan) }
		#expect(throws: CalendarError.nonFiniteValue) { try date.adding(days: 1, fractionalDay: .infinity) }
	}

	@Test func addingDoubleDays() throws {
		let date = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.75, .gregorian)
		#expect(try date.adding(days: 0.0) == date)
		#expect(try date.adding(days: 0.25) == CalendarDate(year: 2000, month: 1, day: 2, .gregorian))
		#expect(try date.adding(days: 1.5) == CalendarDate(year: 2000, month: 1, day: 3, fractionSinceMidnight: 0.25, .gregorian))
		#expect(try date.adding(days: -0.5) == CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .gregorian))
		#expect(try date.adding(days: -0.75) == CalendarDate(year: 2000, month: 1, day: 1, .gregorian))
		#expect(try date.adding(days: -1.0) == CalendarDate(year: 1999, month: 12, day: 31, fractionSinceMidnight: 0.75, .gregorian))

		let midnight = try CalendarDate(year: 2000, month: 1, day: 1, .gregorian)
		#expect(try midnight.adding(days: -0.25) == CalendarDate(year: 1999, month: 12, day: 31, fractionSinceMidnight: 0.75, .gregorian))

		#expect(throws: CalendarError.nonFiniteValue) { try date.adding(days: .nan) }
		#expect(throws: CalendarError.nonFiniteValue) { try date.adding(days: .infinity) }
		#expect(throws: CalendarError.nonFiniteValue) { try date.adding(days: -.infinity) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try date.adding(days: 1e300) }
	}

	@Test func addingDaysPreservesCalendar() throws {
		let julian = try CalendarDate(year: 1900, month: 2, day: 28, fractionSinceMidnight: 0.5, .julian)
		let next = try julian.adding(days: 1)
		#expect(next.calendar == .julian)
		#expect(next == (try CalendarDate(year: 1900, month: 2, day: 29, fractionSinceMidnight: 0.5, .julian)))

		let changeover = try CalendarDate(year: 1582, month: 10, day: 4, fractionSinceMidnight: 0.5, .julianGregorian)
		#expect(try changeover.adding(days: 1) == CalendarDate(year: 1582, month: 10, day: 15, fractionSinceMidnight: 0.5, .julianGregorian))
		#expect(try changeover.adding(days: 0.5) == CalendarDate(year: 1582, month: 10, day: 15, .julianGregorian))
	}

	@Test func addingDaysOverflowThrows() throws {
		let last = CalendarDate(calendarDay: CalendarDay(julianDayNumber: .max, .gregorian), uncheckedFractionSinceMidnight: 0.5)
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try last.adding(days: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try last.adding(days: 0, fractionalDay: 0.5) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try last.adding(days: 0.5) }
		#expect(try last.adding(days: 0.25).julianDayNumber == .max)

		let first = CalendarDate(calendarDay: CalendarDay(julianDayNumber: .min, .julian), uncheckedFractionSinceMidnight: 0)
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try first.adding(days: -1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try first.adding(days: -0.25) }
	}

	@Test func normalized() throws {
		let day = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		#expect(try CalendarDate.normalized(calendarDay: day, fractionSinceMidnight: 0.5) == CalendarDate(calendarDay: day, fractionSinceMidnight: 0.5))
		#expect(try CalendarDate.normalized(calendarDay: day, fractionSinceMidnight: 2.25) == CalendarDate(year: 2000, month: 1, day: 3, fractionSinceMidnight: 0.25, .gregorian))
		#expect(try CalendarDate.normalized(calendarDay: day, fractionSinceMidnight: 1) == CalendarDate(year: 2000, month: 1, day: 2, .gregorian))
		#expect(try CalendarDate.normalized(calendarDay: day, fractionSinceMidnight: -0.25) == CalendarDate(year: 1999, month: 12, day: 31, fractionSinceMidnight: 0.75, .gregorian))
		#expect(try CalendarDate.normalized(calendarDay: day, fractionSinceMidnight: -1) == CalendarDate(year: 1999, month: 12, day: 31, .gregorian))

		#expect(try CalendarDate.normalized(year: 2000, month: 13, day: 1, fractionSinceMidnight: 1.5, .gregorian) == CalendarDate(year: 2001, month: 1, day: 2, fractionSinceMidnight: 0.5, .gregorian))
		#expect(try CalendarDate.normalized(year: 1900, month: 2, day: 29, fractionSinceMidnight: 0, .gregorian) == CalendarDate(year: 1900, month: 3, day: 1, .gregorian))
		#expect(try CalendarDate.normalized(year: 1900, month: 2, day: 29, fractionSinceMidnight: 0, .julian) == CalendarDate(year: 1900, month: 2, day: 29, .julian))
		#expect(try CalendarDate.normalized(year: 1582, month: 10, day: 4, fractionSinceMidnight: 1.25, .julianGregorian) == CalendarDate(year: 1582, month: 10, day: 15, fractionSinceMidnight: 0.25, .julianGregorian))

		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate.normalized(calendarDay: day, fractionSinceMidnight: .nan) }
		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate.normalized(year: 2000, month: 1, day: 1, fractionSinceMidnight: .infinity, .julian) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDate.normalized(year: .max, month: 1, day: 1, fractionSinceMidnight: 0, .gregorian) }
	}

	// MARK: - Decimal Years

	@Test func decimalYear() throws {
		#expect(try CalendarDate(year: 1985, month: 1, day: 1, .gregorian).decimalYear == 1985)
		#expect(try CalendarDate(year: 1985, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian).decimalYear == 1985 + 0.5 / 365)
		#expect(try CalendarDate(year: 1985, month: 7, day: 2, fractionSinceMidnight: 0.5, .gregorian).decimalYear == 1985.5)
		#expect(try CalendarDate(year: 2024, month: 10, day: 1, fractionSinceMidnight: 0.5, .gregorian).decimalYear == 2024.75)
		#expect(try CalendarDate(year: 1582, month: 6, day: 27, fractionSinceMidnight: 0.5, .julianGregorian).decimalYear == 1582.5)

		// Agrees with the calendar day at midnight
		let day = try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian)
		#expect(try CalendarDate(calendarDay: day, fractionSinceMidnight: 0).decimalYear == day.decimalYear)
	}

	@Test func initFromDecimalYear() throws {
		#expect(try CalendarDate(decimalYear: 1985, .gregorian) == CalendarDate(year: 1985, month: 1, day: 1, .gregorian))
		#expect(try CalendarDate(decimalYear: 1985.25, .gregorian) == CalendarDate(year: 1985, month: 4, day: 2, fractionSinceMidnight: 0.25, .gregorian))
		#expect(try CalendarDate(decimalYear: 1985.5, .gregorian) == CalendarDate(year: 1985, month: 7, day: 2, fractionSinceMidnight: 0.5, .gregorian))
		#expect(try CalendarDate(decimalYear: 2000.5, .gregorian) == CalendarDate(year: 2000, month: 7, day: 2, .gregorian))
		#expect(try CalendarDate(decimalYear: 2024.75, .gregorian) == CalendarDate(year: 2024, month: 10, day: 1, fractionSinceMidnight: 0.5, .gregorian))
		#expect(try CalendarDate(decimalYear: -0.5, .julian) == CalendarDate(year: -1, month: 7, day: 2, fractionSinceMidnight: 0.5, .julian))
		#expect(try CalendarDate(decimalYear: 1582.5, .julianGregorian) == CalendarDate(year: 1582, month: 6, day: 27, fractionSinceMidnight: 0.5, .julianGregorian))
		#expect(try CalendarDate(decimalYear: 1582 + 277.0 / 355, .julianGregorian) == CalendarDate(year: 1582, month: 10, day: 15, .julianGregorian))

		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate(decimalYear: .nan, .gregorian) }
		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDate(decimalYear: -.infinity, .julian) }
		#expect(throws: CalendarError.invalidDecimalYear) { try CalendarDate(decimalYear: 1e300, .julianGregorian) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDate(decimalYear: 1e18, .gregorian) }
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func decimalYearRoundTrip(_ calendar: CalendarIdentifier) throws {
		let fractions = [0, 0.125, 0.25, 0.5, 0.75, 0.999]
		for J in stride(from: 2_298_000, through: 2_301_000, by: 7) {
			for f in fractions {
				let date = CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), uncheckedFractionSinceMidnight: f)
				let roundTripped = try CalendarDate(decimalYear: date.decimalYear, calendar)
				#expect(roundTripped.calendarDay == date.calendarDay, "J = \(J), f = \(f)")
				#expect(abs(roundTripped.fractionSinceMidnight - f) < 1e-9, "J = \(J), f = \(f)")
			}
		}
	}

	@Test func decimalYearIsMonotonic() throws {
		var previous = -Double.infinity
		var date = try CalendarDate(year: 1581, month: 12, day: 31, .julianGregorian)
		for _ in 0 ..< 1_000 {
			let decimalYear = date.decimalYear
			#expect(decimalYear > previous, "\(date)")
			previous = decimalYear
			date = try date.adding(days: 0.5)
		}
	}

	// MARK: - Conversion and Comparison

	@Test func convertedTo() throws {
		let gregorian = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)
		let julian = gregorian.convertedTo(.julian)
		#expect(julian == (try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, .julian)))
		#expect(julian.convertedTo(.gregorian) == gregorian)
		#expect(gregorian.convertedTo(.gregorian) == gregorian)
		#expect(julian.julianDayNumber == gregorian.julianDayNumber)
		#expect(julian.fractionSinceMidnight == gregorian.fractionSinceMidnight)
	}

	@Test func isSameInstantAs() throws {
		let gregorian = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)
		let julian = try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, .julian)
		#expect(gregorian.isSameInstantAs(julian))
		#expect(julian.isSameInstantAs(gregorian))
		#expect(gregorian != julian)
		#expect(try !gregorian.isSameInstantAs(CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.25, .julian)))
		#expect(try !gregorian.isSameInstantAs(CalendarDate(year: 1999, month: 12, day: 20, fractionSinceMidnight: 0.5, .julian)))
	}

	@Test func equalityAndHashing() throws {
		let a = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)
		let b = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)
		let c = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .gregorian)
		let d = a.convertedTo(.julianGregorian)
		#expect(a == b)
		#expect(a.hashValue == b.hashValue)
		#expect(a != c)
		#expect(a != d)
		#expect(Set([a, b, c, d]).count == 3)
	}

	@Test func comparison() throws {
		let a = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .gregorian)
		let b = try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, .julian)
		let c = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)
		let d = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .julianGregorian)
		let e = try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.75, .julian)
		let f = try CalendarDate(year: 2000, month: 1, day: 2, .gregorian)

		// Earlier time of day on the same day, regardless of calendar
		#expect(a < b)
		#expect(!(b < a))
		// Ties on the same instant are broken by calendar: Julian, Gregorian, Julian-Gregorian
		#expect(b < c)
		#expect(c < d)
		#expect(!(c < c))
		// A later time of day in a calendar that sorts first is still later
		#expect(d < e)
		#expect(e < f)

		#expect([f, e, d, c, b, a].sorted() == [a, b, c, d, e, f])
	}

	// MARK: - Day Intervals

	@Test func intervalTo() throws {
		let start = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .gregorian)
		let end = try CalendarDate(year: 2000, month: 1, day: 3, fractionSinceMidnight: 0.75, .gregorian)
		#expect(try start.interval(to: end).inDays == 2.5)
		#expect(try end.interval(to: start).inDays == -2.5)
		#expect(try start.interval(to: end) == DayInterval(days: 2, fractionalDay: 0.5))
		#expect(try start.interval(to: start) == .zero)

		// Independent of calendar
		#expect(try start.interval(to: start.convertedTo(.julian)) == .zero)
		#expect(try start.interval(to: end.convertedTo(.julian)).inDays == 2.5)

		// Across the changeover
		let october4 = try CalendarDate(year: 1582, month: 10, day: 4, fractionSinceMidnight: 0.5, .julianGregorian)
		let october15 = try CalendarDate(year: 1582, month: 10, day: 15, .julianGregorian)
		#expect(try october4.interval(to: october15).inDays == 0.5)
	}

	@Test func intervalOverflowThrows() {
		let first = CalendarDate(calendarDay: CalendarDay(julianDayNumber: .min, .julian), uncheckedFractionSinceMidnight: 0)
		let last = CalendarDate(calendarDay: CalendarDay(julianDayNumber: .max, .gregorian), uncheckedFractionSinceMidnight: 0)
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try first.interval(to: last) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try last.interval(to: first) }
	}

	@Test func addingAndSubtractingInterval() throws {
		let date = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .julian)
		let interval = try DayInterval(days: 2, fractionalDay: 0.5)
		let later = try date.adding(interval)
		#expect(later == (try CalendarDate(year: 2000, month: 1, day: 3, fractionSinceMidnight: 0.75, .julian)))
		#expect(later.calendar == .julian)
		#expect(try later.subtracting(interval) == date)
		#expect(try date.subtracting(interval) == CalendarDate(year: 1999, month: 12, day: 29, fractionSinceMidnight: 0.75, .julian))
		#expect(try date.adding(.zero) == date)
		#expect(try date.subtracting(.zero) == date)

		let changeover = try CalendarDate(year: 1582, month: 10, day: 4, fractionSinceMidnight: 0.75, .julianGregorian)
		#expect(try changeover.adding(DayInterval(days: 0.5)) == CalendarDate(year: 1582, month: 10, day: 15, fractionSinceMidnight: 0.25, .julianGregorian))
	}

	@Test func intervalRoundTrip() throws {
		let start = try CalendarDate(year: 1600, month: 2, day: 29, fractionSinceMidnight: 0.125, .gregorian)
		for (days, fraction) in [(0, 0.0), (1, 0.5), (365, 0.75), (-1, 0.875), (-146_097, 0.25), (1_000_000, 0.0625)] {
			let end = try start.adding(days: days, fractionalDay: fraction)
			let interval = try start.interval(to: end)
			#expect(try start.adding(interval) == end)
			#expect(try end.subtracting(interval) == start)
		}
	}

	@Test func addingIntervalOverflowThrows() throws {
		let last = CalendarDate(calendarDay: CalendarDay(julianDayNumber: .max, .gregorian), uncheckedFractionSinceMidnight: 0)
		let first = CalendarDate(calendarDay: CalendarDay(julianDayNumber: .min, .gregorian), uncheckedFractionSinceMidnight: 0)
		let oneDay = try DayInterval(days: 1)
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try last.adding(oneDay) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try first.subtracting(oneDay) }
	}

	// MARK: - Descriptions

	@Test func descriptions() throws {
		let date = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)
		#expect(date.description == "2000-1-1 +0.5 (Gregorian)")
		#expect(date.debugDescription == "CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: Gregorian)")
		#expect(try CalendarDate(year: -44, month: 3, day: 15, .julian).description == "-44-3-15 +0.0 (Julian)")
		#expect(try CalendarDate(year: 1582, month: 10, day: 15, fractionSinceMidnight: 0.25, .julianGregorian).description == "1582-10-15 +0.25 (Julian-Gregorian)")
	}
}

#if canImport(Foundation)

import Foundation

/// An unvalidated calendar date payload with the same coding keys as `CalendarDate`.
private struct RawCalendarDate: Encodable {
	let year: Int
	let month: Int
	let day: Int
	let fractionSinceMidnight: Double
	let calendar: CalendarIdentifier
}

@Suite struct CalendarDateCodableTests {
	// MARK: - Coding

	@Test(arguments: CalendarIdentifier.allCases)
	func codableRoundTrip(_ calendar: CalendarIdentifier) throws {
		for (J, f) in [(-1_931_076, 0.0), (0, 0.5), (2_299_160, 0.75), (2_299_161, 0.1), (2_451_545, Double(1).nextDown)] {
			let date = CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), uncheckedFractionSinceMidnight: f)
			let data = try JSONEncoder().encode(date)
			#expect(try JSONDecoder().decode(CalendarDate.self, from: data) == date)
		}
	}

	@Test func decodingInvalidDateThrows() throws {
		let invalidDay = try JSONEncoder().encode(RawCalendarDate(year: 2001, month: 2, day: 29, fractionSinceMidnight: 0, calendar: .gregorian))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(CalendarDate.self, from: invalidDay) }

		let invalidFraction = try JSONEncoder().encode(RawCalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 1, calendar: .gregorian))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(CalendarDate.self, from: invalidFraction) }

		let negativeFraction = try JSONEncoder().encode(RawCalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: -0.5, calendar: .julian))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(CalendarDate.self, from: negativeFraction) }

		let unrepresentable = try JSONEncoder().encode(RawCalendarDate(year: .min, month: 1, day: 1, fractionSinceMidnight: 0, calendar: .julianGregorian))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(CalendarDate.self, from: unrepresentable) }

		let encoder = JSONEncoder()
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
		let decoder = JSONDecoder()
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
		let nonFinite = try encoder.encode(RawCalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: .nan, calendar: .gregorian))
		#expect(throws: DecodingError.self) { try decoder.decode(CalendarDate.self, from: nonFinite) }
	}
}

#endif
