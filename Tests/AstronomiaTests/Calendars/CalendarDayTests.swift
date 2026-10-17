//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// A year, month, and day in a calendar, used as a test argument.
struct CalendarDayTestComponents: Sendable, CustomTestStringConvertible {
	let year: Int
	let month: Int
	let day: Int
	let calendar: CalendarIdentifier

	init(_ year: Int, _ month: Int, _ day: Int, _ calendar: CalendarIdentifier) {
		self.year = year
		self.month = month
		self.day = day
		self.calendar = calendar
	}

	var testDescription: String {
		"\(year)-\(month)-\(day) (\(calendar.name))"
	}
}

@Suite struct CalendarDayTests {
	// MARK: - Creation

	@Test func initFromComponents() throws {
		let day = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		#expect(day.year == 2000)
		#expect(day.month == 1)
		#expect(day.day == 1)
		#expect(day.calendar == .gregorian)
		#expect(day.julianDayNumber == 2_451_545)
		#expect(day.components == (2000, 1, 1))

		#expect(try CalendarDay(year: 1999, month: 12, day: 19, .julian).julianDayNumber == 2_451_545)
		#expect(try CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian).julianDayNumber == 2_299_160)
		#expect(try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian).julianDayNumber == 2_299_161)
		#expect(try CalendarDay(year: -4712, month: 1, day: 1, .julian).julianDayNumber == 0)
		#expect(try CalendarDay(year: -4713, month: 11, day: 24, .gregorian).julianDayNumber == 0)
	}

	@Test(arguments: [
		CalendarDayTestComponents(2001, 2, 29, .gregorian),
		CalendarDayTestComponents(1900, 2, 29, .gregorian),
		CalendarDayTestComponents(1900, 2, 29, .julianGregorian),
		CalendarDayTestComponents(-1, 2, 29, .julian),
		CalendarDayTestComponents(2000, 0, 1, .julian),
		CalendarDayTestComponents(2000, 13, 1, .julian),
		CalendarDayTestComponents(2000, 1, 0, .gregorian),
		CalendarDayTestComponents(2000, 1, -1, .gregorian),
		CalendarDayTestComponents(2000, 4, 31, .gregorian),
		CalendarDayTestComponents(1582, 10, 5, .julianGregorian),
		CalendarDayTestComponents(1582, 10, 14, .julianGregorian),
	])
	func initFromInvalidComponentsThrows(_ c: CalendarDayTestComponents) {
		#expect(throws: CalendarError.invalidDate) { try CalendarDay(year: c.year, month: c.month, day: c.day, c.calendar) }
	}

	@Test(arguments: [
		CalendarDayTestComponents(1900, 2, 29, .julian),
		CalendarDayTestComponents(-4, 2, 29, .julian),
		CalendarDayTestComponents(-4, 2, 29, .gregorian),
		CalendarDayTestComponents(1582, 10, 10, .julian),
		CalendarDayTestComponents(1582, 10, 10, .gregorian),
		CalendarDayTestComponents(1600, 2, 29, .julianGregorian),
		CalendarDayTestComponents(1500, 2, 29, .julianGregorian),
	])
	func initFromValidComponents(_ c: CalendarDayTestComponents) throws {
		let calendarDay = try CalendarDay(year: c.year, month: c.month, day: c.day, c.calendar)
		#expect(calendarDay.components == (c.year, c.month, c.day))
		#expect(calendarDay.calendar == c.calendar)
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func initFromUnrepresentableComponentsThrows(_ calendar: CalendarIdentifier) {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(year: .max, month: 1, day: 1, calendar) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(year: .min, month: 1, day: 1, calendar) }
	}

	@Test func initFromJulianDayNumber() {
		#expect(CalendarDay(julianDayNumber: 2_451_545, .gregorian).components == (2000, 1, 1))
		#expect(CalendarDay(julianDayNumber: 2_451_545, .julian).components == (1999, 12, 19))
		#expect(CalendarDay(julianDayNumber: 2_451_545, .julianGregorian).components == (2000, 1, 1))
		#expect(CalendarDay(julianDayNumber: 2_299_160, .julianGregorian).components == (1582, 10, 4))
		#expect(CalendarDay(julianDayNumber: 2_299_161, .julianGregorian).components == (1582, 10, 15))
		#expect(CalendarDay(julianDayNumber: 0, .julian).components == (-4712, 1, 1))
		#expect(CalendarDay(julianDayNumber: 0, .gregorian).components == (-4713, 11, 24))
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func julianDayNumberRoundTrip(_ calendar: CalendarIdentifier) throws {
		for J in 2_298_800 ... 2_299_600 {
			let day = CalendarDay(julianDayNumber: J, calendar)
			#expect(day.julianDayNumber == J)
			#expect(try CalendarDay(year: day.year, month: day.month, day: day.day, calendar) == day)
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func extremeJulianDayNumbers(_ calendar: CalendarIdentifier) throws {
		let first = CalendarDay(julianDayNumber: .min, calendar)
		let last = CalendarDay(julianDayNumber: .max, calendar)
		#expect(try CalendarDay(year: first.year, month: first.month, day: first.day, calendar) == first)
		#expect(try CalendarDay(year: last.year, month: last.month, day: last.day, calendar) == last)
	}

	@Test func normalized() throws {
		#expect(try CalendarDay.normalized(year: 2000, month: 2, day: 30, .gregorian) == CalendarDay(year: 2000, month: 3, day: 1, .gregorian))
		#expect(try CalendarDay.normalized(year: 2000, month: 2, day: 30, .julian) == CalendarDay(year: 2000, month: 3, day: 1, .julian))
		#expect(try CalendarDay.normalized(year: 1900, month: 2, day: 29, .gregorian) == CalendarDay(year: 1900, month: 3, day: 1, .gregorian))
		#expect(try CalendarDay.normalized(year: 2000, month: 13, day: 1, .gregorian) == CalendarDay(year: 2001, month: 1, day: 1, .gregorian))
		#expect(try CalendarDay.normalized(year: 2000, month: 0, day: 0, .gregorian) == CalendarDay(year: 1999, month: 11, day: 30, .gregorian))
		#expect(try CalendarDay.normalized(year: 2000, month: 1, day: 366, .gregorian) == CalendarDay(year: 2000, month: 12, day: 31, .gregorian))
		// The nonexistent dates October 5-14, 1582 count forward from October 4
		#expect(try CalendarDay.normalized(year: 1582, month: 10, day: 10, .julianGregorian) == CalendarDay(year: 1582, month: 10, day: 20, .julianGregorian))
		// Valid days are unchanged
		#expect(try CalendarDay.normalized(year: 1582, month: 10, day: 4, .julianGregorian) == CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian))

		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay.normalized(year: .max, month: 1, day: 1, .gregorian) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay.normalized(year: 1, month: .max, day: 1, .julian) }
	}

	// MARK: - Properties

	@Test func isInLeapYear() throws {
		#expect(try CalendarDay(year: 1900, month: 1, day: 1, .julian).isInLeapYear)
		#expect(try !CalendarDay(year: 1900, month: 1, day: 1, .gregorian).isInLeapYear)
		#expect(try !CalendarDay(year: 1900, month: 1, day: 1, .julianGregorian).isInLeapYear)
		#expect(try CalendarDay(year: 1500, month: 1, day: 1, .julianGregorian).isInLeapYear)
		#expect(try CalendarDay(year: 2000, month: 12, day: 31, .gregorian).isInLeapYear)
		#expect(try !CalendarDay(year: 1582, month: 6, day: 1, .julianGregorian).isInLeapYear)
	}

	@Test func numberOfMonthsInYear() throws {
		for calendar in CalendarIdentifier.allCases {
			#expect(try CalendarDay(year: 2000, month: 1, day: 1, calendar).numberOfMonthsInYear == 12)
		}
	}

	@Test func numberOfDaysInMonth() throws {
		#expect(try CalendarDay(year: 2000, month: 2, day: 1, .gregorian).numberOfDaysInMonth == 29)
		#expect(try CalendarDay(year: 1900, month: 2, day: 1, .gregorian).numberOfDaysInMonth == 28)
		#expect(try CalendarDay(year: 1900, month: 2, day: 1, .julian).numberOfDaysInMonth == 29)
		#expect(try CalendarDay(year: 2001, month: 4, day: 30, .gregorian).numberOfDaysInMonth == 30)
		#expect(try CalendarDay(year: 2001, month: 12, day: 31, .julian).numberOfDaysInMonth == 31)
		#expect(try CalendarDay(year: 1582, month: 10, day: 1, .julian).numberOfDaysInMonth == 31)
		#expect(try CalendarDay(year: 1582, month: 10, day: 1, .julianGregorian).numberOfDaysInMonth == 21)
		#expect(try CalendarDay(year: 1582, month: 10, day: 31, .julianGregorian).numberOfDaysInMonth == 21)
		#expect(try CalendarDay(year: 1582, month: 9, day: 1, .julianGregorian).numberOfDaysInMonth == 30)
		#expect(try CalendarDay(year: 1582, month: 11, day: 1, .julianGregorian).numberOfDaysInMonth == 30)
	}

	@Test func numberOfDaysInYear() throws {
		#expect(try CalendarDay(year: 2000, month: 1, day: 1, .gregorian).numberOfDaysInYear == 366)
		#expect(try CalendarDay(year: 1900, month: 1, day: 1, .gregorian).numberOfDaysInYear == 365)
		#expect(try CalendarDay(year: 1900, month: 1, day: 1, .julian).numberOfDaysInYear == 366)
		#expect(try CalendarDay(year: 1582, month: 1, day: 1, .julian).numberOfDaysInYear == 365)
		#expect(try CalendarDay(year: 1582, month: 1, day: 1, .gregorian).numberOfDaysInYear == 365)
		#expect(try CalendarDay(year: 1582, month: 1, day: 1, .julianGregorian).numberOfDaysInYear == 355)
	}

	@Test func dayOfWeek() throws {
		// Saturday, January 1, 2000 (Gregorian)
		#expect(try CalendarDay(year: 2000, month: 1, day: 1, .gregorian).dayOfWeek == 7)
		#expect(try CalendarDay(year: 1999, month: 12, day: 19, .julian).dayOfWeek == 7)
		// Sunday, July 20, 1969
		#expect(try CalendarDay(year: 1969, month: 7, day: 20, .gregorian).dayOfWeek == 1)
		// Thursday, October 4, 1582 was followed by Friday, October 15, 1582
		#expect(try CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian).dayOfWeek == 5)
		#expect(try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian).dayOfWeek == 6)
		// Monday, January 1, 4713 BCE
		#expect(CalendarDay(julianDayNumber: 0, .julian).dayOfWeek == 2)
	}

	@Test func dayOfYear() throws {
		#expect(try CalendarDay(year: 2000, month: 1, day: 1, .gregorian).dayOfYear == 1)
		#expect(try CalendarDay(year: 2000, month: 12, day: 31, .gregorian).dayOfYear == 366)
		#expect(try CalendarDay(year: 1900, month: 3, day: 1, .gregorian).dayOfYear == 60)
		#expect(try CalendarDay(year: 1900, month: 3, day: 1, .julian).dayOfYear == 61)
		#expect(try CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian).dayOfYear == 277)
		#expect(try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian).dayOfYear == 278)
		#expect(try CalendarDay(year: 1582, month: 12, day: 31, .julianGregorian).dayOfYear == 355)
		#expect(try CalendarDay(year: 1582, month: 12, day: 31, .gregorian).dayOfYear == 365)
	}

	// MARK: - Decimal Years

	@Test func decimalYear() throws {
		#expect(try CalendarDay(year: 1985, month: 1, day: 1, .gregorian).decimalYear == 1985)
		#expect(try CalendarDay(year: 1985, month: 7, day: 2, .gregorian).decimalYear == 1985 + 182.0 / 365)
		#expect(try CalendarDay(year: 2000, month: 7, day: 2, .gregorian).decimalYear == 2000.5)
		#expect(try CalendarDay(year: -1, month: 1, day: 1, .julian).decimalYear == -1)
		#expect(try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian).decimalYear == 1582 + 277.0 / 355)
	}

	@Test func initFromDecimalYear() throws {
		#expect(try CalendarDay(decimalYear: 1985, .gregorian) == CalendarDay(year: 1985, month: 1, day: 1, .gregorian))
		#expect(try CalendarDay(decimalYear: 1985.5, .gregorian) == CalendarDay(year: 1985, month: 7, day: 2, .gregorian))
		#expect(try CalendarDay(decimalYear: 2000.5, .gregorian) == CalendarDay(year: 2000, month: 7, day: 2, .gregorian))
		#expect(try CalendarDay(decimalYear: -0.5, .julian) == CalendarDay(year: -1, month: 7, day: 2, .julian))
		#expect(try CalendarDay(decimalYear: -1e-20, .julian) == CalendarDay(year: -1, month: 12, day: 31, .julian))
		#expect(try CalendarDay(decimalYear: 1582 + 277.0 / 355, .julianGregorian) == CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian))
		#expect(try CalendarDay(decimalYear: 1582 + 276.0 / 355, .julianGregorian) == CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian))

		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDay(decimalYear: .nan, .gregorian) }
		#expect(throws: CalendarError.nonFiniteValue) { try CalendarDay(decimalYear: .infinity, .julian) }
		#expect(throws: CalendarError.invalidDecimalYear) { try CalendarDay(decimalYear: 1e300, .julianGregorian) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(decimalYear: 1e18, .gregorian) }
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func decimalYearRoundTrip(_ calendar: CalendarIdentifier) throws {
		for J in stride(from: -1_000_000, through: 3_000_000, by: 997) {
			let day = CalendarDay(julianDayNumber: J, calendar)
			#expect(try CalendarDay(decimalYear: day.decimalYear, calendar) == day, "J = \(J)")
		}
		// Every day of the changeover year and its neighbors
		for J in 2_298_400 ... 2_299_700 {
			let day = CalendarDay(julianDayNumber: J, calendar)
			#expect(try CalendarDay(decimalYear: day.decimalYear, calendar) == day, "J = \(J)")
		}
	}

	// MARK: - Conversion and Comparison

	@Test func convertedTo() throws {
		let gregorian = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		let julian = gregorian.convertedTo(.julian)
		#expect(julian.components == (1999, 12, 19))
		#expect(julian.calendar == .julian)
		#expect(julian.julianDayNumber == gregorian.julianDayNumber)
		#expect(julian.convertedTo(.gregorian) == gregorian)
		#expect(gregorian.convertedTo(.gregorian) == gregorian)
		#expect(gregorian.convertedTo(.julianGregorian).components == (2000, 1, 1))

		let medieval = try CalendarDay(year: 1066, month: 10, day: 14, .julianGregorian)
		#expect(medieval.convertedTo(.julian).components == (1066, 10, 14))
		#expect(medieval.convertedTo(.gregorian).components == (1066, 10, 20))
	}

	@Test func isSameDayAs() throws {
		let gregorian = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		let julian = try CalendarDay(year: 1999, month: 12, day: 19, .julian)
		let hybrid = try CalendarDay(year: 2000, month: 1, day: 1, .julianGregorian)
		#expect(gregorian.isSameDayAs(julian))
		#expect(julian.isSameDayAs(hybrid))
		#expect(gregorian.isSameDayAs(gregorian))
		#expect(try !gregorian.isSameDayAs(CalendarDay(year: 2000, month: 1, day: 1, .julian)))
	}

	@Test func equalityAndHashing() throws {
		let gregorian = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		let julian = try CalendarDay(year: 1999, month: 12, day: 19, .julian)
		#expect(gregorian == (try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)))
		#expect(gregorian == CalendarDay(julianDayNumber: 2_451_545, .gregorian))
		// The same day in different calendars is not equal
		#expect(gregorian != julian)
		#expect(gregorian != gregorian.convertedTo(.julianGregorian))
		#expect(gregorian.hashValue == CalendarDay(julianDayNumber: 2_451_545, .gregorian).hashValue)

		let set: Set = [gregorian, julian, CalendarDay(julianDayNumber: 2_451_545, .gregorian), CalendarDay(julianDayNumber: 2_451_545, .julian)]
		#expect(set.count == 2)
	}

	@Test func comparison() throws {
		let a = try CalendarDay(year: 1999, month: 12, day: 31, .gregorian)
		let b = try CalendarDay(year: 1999, month: 12, day: 19, .julian)
		let c = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		let d = try CalendarDay(year: 2000, month: 1, day: 1, .julianGregorian)
		let e = try CalendarDay(year: 2000, month: 1, day: 2, .julian)

		#expect(a < b)
		#expect(!(b < a))
		// Ties on the same day are broken by calendar: Julian, Gregorian, Julian-Gregorian
		#expect(b < c)
		#expect(c < d)
		#expect(b < d)
		#expect(!(c < c))
		#expect(d < e)

		#expect([e, d, c, b, a].sorted() == [a, b, c, d, e])
	}

	// MARK: - Arithmetic

	@Test func addingDays() throws {
		let leapDay = try CalendarDay(year: 2000, month: 2, day: 28, .gregorian)
		#expect(try leapDay.adding(days: 1) == CalendarDay(year: 2000, month: 2, day: 29, .gregorian))
		#expect(try leapDay.adding(days: 2) == CalendarDay(year: 2000, month: 3, day: 1, .gregorian))
		#expect(try leapDay.adding(days: -59) == CalendarDay(year: 1999, month: 12, day: 31, .gregorian))
		#expect(try leapDay.adding(days: 0) == leapDay)
		#expect(try leapDay.adding(days: 146_097) == CalendarDay(year: 2400, month: 2, day: 28, .gregorian))

		let julian = try CalendarDay(year: 1900, month: 2, day: 28, .julian)
		#expect(try julian.adding(days: 1) == CalendarDay(year: 1900, month: 2, day: 29, .julian))
		#expect(try julian.adding(days: 1).calendar == .julian)

		let changeover = try CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian)
		#expect(try changeover.adding(days: 1) == CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian))
		#expect(try changeover.adding(days: 1).adding(days: -1) == changeover)
	}

	@Test func addingDaysOverflowThrows() {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(julianDayNumber: .max, .gregorian).adding(days: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(julianDayNumber: .min, .julian).adding(days: -1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(julianDayNumber: 1, .julianGregorian).adding(days: .max) }
	}

	@Test func subtractingDays() throws {
		let march1 = try CalendarDay(year: 2000, month: 3, day: 1, .gregorian)
		#expect(try march1.subtracting(days: 1) == CalendarDay(year: 2000, month: 2, day: 29, .gregorian))
		#expect(try march1.subtracting(days: 2) == CalendarDay(year: 2000, month: 2, day: 28, .gregorian))
		#expect(try march1.subtracting(days: 61) == CalendarDay(year: 1999, month: 12, day: 31, .gregorian))
		#expect(try march1.subtracting(days: -1) == CalendarDay(year: 2000, month: 3, day: 2, .gregorian))
		#expect(try march1.subtracting(days: 0) == march1)
		#expect(try march1.subtracting(days: 146_097) == CalendarDay(year: 1600, month: 3, day: 1, .gregorian))

		let julian = try CalendarDay(year: 1900, month: 3, day: 1, .julian)
		#expect(try julian.subtracting(days: 1) == CalendarDay(year: 1900, month: 2, day: 29, .julian))
		#expect(try julian.subtracting(days: 1).calendar == .julian)

		let october15 = try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian)
		#expect(try october15.subtracting(days: 1) == CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian))
		#expect(try october15.subtracting(days: 1).adding(days: 1) == october15)

		// Inverse of addition
		for n in [-1_000_000, -1, 0, 1, 365, 1_000_000] {
			#expect(try march1.subtracting(days: n) == march1.adding(days: -n))
			#expect(try march1.adding(days: n).subtracting(days: n) == march1)
			#expect(try march1.subtracting(days: n).days(to: march1) == n)
		}

		// Subtracting Int.min has no adding(days:) equivalent but is representable from a negative JDN
		#expect(try CalendarDay(julianDayNumber: -1, .gregorian).subtracting(days: .min).julianDayNumber == .max)
	}

	@Test func subtractingDaysOverflowThrows() {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(julianDayNumber: .min, .julian).subtracting(days: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(julianDayNumber: .max, .gregorian).subtracting(days: -1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(julianDayNumber: -2, .julianGregorian).subtracting(days: .max) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try CalendarDay(julianDayNumber: 0, .gregorian).subtracting(days: .min) }
	}

	@Test func daysToDay() throws {
		let start = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		let end = try CalendarDay(year: 2001, month: 1, day: 1, .gregorian)
		#expect(try start.days(to: end) == 366)
		#expect(try end.days(to: start) == -366)
		#expect(try start.days(to: start) == 0)

		// Independent of calendar
		#expect(try start.days(to: CalendarDay(year: 1999, month: 12, day: 19, .julian)) == 0)
		#expect(try start.days(to: CalendarDay(year: 2000, month: 1, day: 1, .julian)) == 13)

		let october4 = try CalendarDay(year: 1582, month: 10, day: 4, .julianGregorian)
		let october15 = try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian)
		#expect(try october4.days(to: october15) == 1)

		for n in [-1_000_000, -1, 0, 1, 365, 1_000_000] {
			#expect(try start.days(to: start.adding(days: n)) == n)
		}
	}

	@Test func daysToDayOverflowThrows() {
		let first = CalendarDay(julianDayNumber: .min, .julian)
		let last = CalendarDay(julianDayNumber: .max, .gregorian)
		#expect(throws: CalendarError.dayCountNotRepresentable) { try first.days(to: last) }
		#expect(throws: CalendarError.dayCountNotRepresentable) { try last.days(to: first) }
	}

	// MARK: - Descriptions

	@Test func descriptions() throws {
		let day = try CalendarDay(year: 2000, month: 1, day: 1, .gregorian)
		#expect(day.description == "2000-1-1 (Gregorian)")
		#expect(day.debugDescription == "CalendarDay(year: 2000, month: 1, day: 1, calendar: Gregorian)")
		#expect(try CalendarDay(year: -44, month: 3, day: 15, .julian).description == "-44-3-15 (Julian)")
		#expect(try CalendarDay(year: 1582, month: 10, day: 15, .julianGregorian).description == "1582-10-15 (Julian-Gregorian)")
	}
}

#if canImport(Foundation)

import Foundation

/// An unvalidated calendar day payload with the same coding keys as `CalendarDay`.
private struct RawCalendarDay: Encodable {
	let year: Int
	let month: Int
	let day: Int
	let calendar: CalendarIdentifier
}

@Suite struct CalendarDayCodingTests {
	// MARK: - Coding

	@Test(arguments: CalendarIdentifier.allCases)
	func codableRoundTrip(_ calendar: CalendarIdentifier) throws {
		for J in [-1_931_076, 0, 1_721_424, 2_299_160, 2_299_161, 2_451_545] {
			let day = CalendarDay(julianDayNumber: J, calendar)
			let data = try JSONEncoder().encode(day)
			let decoded = try JSONDecoder().decode(CalendarDay.self, from: data)
			#expect(decoded == day)
			#expect(decoded.components == day.components)
		}
	}

	@Test func decodingInvalidDayThrows() throws {
		let invalid = try JSONEncoder().encode(RawCalendarDay(year: 2001, month: 2, day: 29, calendar: .gregorian))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(CalendarDay.self, from: invalid) }

		let nonexistent = try JSONEncoder().encode(RawCalendarDay(year: 1582, month: 10, day: 10, calendar: .julianGregorian))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(CalendarDay.self, from: nonexistent) }

		let unrepresentable = try JSONEncoder().encode(RawCalendarDay(year: .max, month: 1, day: 1, calendar: .julian))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(CalendarDay.self, from: unrepresentable) }

		let valid = try JSONEncoder().encode(RawCalendarDay(year: 1582, month: 10, day: 10, calendar: .gregorian))
		#expect(try JSONDecoder().decode(CalendarDay.self, from: valid) == CalendarDay(year: 1582, month: 10, day: 10, .gregorian))
	}
}

#endif
