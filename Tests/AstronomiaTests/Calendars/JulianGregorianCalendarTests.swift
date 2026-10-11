//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct JulianGregorianCalendarTests {
	@Test func epoch() throws {
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 1, month: 1, day: 1) == JulianGregorianCalendar.epoch)
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(JulianGregorianCalendar.epoch) == (1, 1, 1))
	}

	@Test func dateValidation() {
		#expect(JulianGregorianCalendar.isValid(year: 1969, month: 7, day: 20))
		#expect(!JulianGregorianCalendar.isValid(year: 1969, month: 7, day: 40))
		#expect(JulianGregorianCalendar.isValid(year: 1600, month: 2, day: 29))
		#expect(!JulianGregorianCalendar.isValidDate((1582, 10, 10)))
	}

	@Test func leapYear() throws {
		#expect(JulianGregorianCalendar.isLeapYear(900))
		#expect(!JulianGregorianCalendar.isLeapYear(1700))

		for y in -1000...2000 {
			let isLeap = JulianGregorianCalendar.isLeapYear(y)
			let j = try JulianGregorianCalendar.julianDayNumberFrom(year: y, month: 2, day: isLeap ? 29 : 28)
			let d = JulianGregorianCalendar.dateFromJulianDayNumber(j)
			#expect(d.month == 2)
			#expect(d.day == (isLeap ? 29 : 28))
		}
	}

	@Test func monthCount() {
		#expect(JulianGregorianCalendar.numberOfMonthsInYear == 12)
	}

	@Test func monthLength() throws {
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 1, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 2, year: 1900) == 28)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 3, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 4, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 5, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 6, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 7, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 8, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 9, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 10, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 11, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 12, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 2, year: 1600) == 29)
	}

	@Test func dayOfYear() throws {
		#expect(try JulianGregorianCalendar.dayOfYearFrom(year: 1500, month: 2, day: 29) == 60)
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dayOfYearFrom(year: 1700, month: 2, day: 29) }
		#expect(try JulianGregorianCalendar.dateFrom(year: 1582, dayOfYear: 277) == (1582, 10, 4))
		#expect(try JulianGregorianCalendar.dateFrom(year: 1582, dayOfYear: 278) == (1582, 10, 15))
		#expect(try JulianGregorianCalendar.dateFrom(year: 1582, dayOfYear: 355) == (1582, 12, 31))

		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dateFrom(year: 1582, dayOfYear: 0) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dateFrom(year: 1582, dayOfYear: 365) }
	}

	@Test func changeover() throws {
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 10, year: 1582) == 21)
		let oct1 = try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 1)
		let oct31 = try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 31)
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 10, year: 1582) == (oct31 - oct1 + 1))

		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 9, year: 1582) == JulianCalendar.numberOfDaysIn(month: 9, year: 1582))
		#expect(try JulianGregorianCalendar.numberOfDaysIn(month: 11, year: 1582) == GregorianCalendar.numberOfDaysIn(month: 11, year: 1582))

		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 3) == true)
		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 4) == true)
		for day in 5...14 {
			#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: day) == false)
		}
		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 15) == true)
		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 16) == true)

		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(GregorianCalendar.papalReform) == (1582, 10, 15))
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 15) == GregorianCalendar.papalReform)

		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(GregorianCalendar.papalReform - 1) == (1582, 10, 4))
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 4) == GregorianCalendar.papalReform - 1)

		#expect(JulianGregorianCalendar.numberOfDaysInYear(1582) == 355)
		let jan1 = try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 1, day: 1)
		let dec31 = try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 12, day: 31)
		#expect(JulianGregorianCalendar.numberOfDaysInYear(1582) == (dec31 - jan1 + 1))

		var sum = 0
		for m in 1...12 {
			sum += try JulianGregorianCalendar.numberOfDaysIn(month: m, year: 1582)
		}

		#expect(JulianGregorianCalendar.numberOfDaysInYear(1582) == sum)
		#expect(sum == (dec31 - jan1 + 1))
		#expect(sum == JulianGregorianCalendar.numberOfDaysInChangeoverYear)
		#expect(JulianGregorianCalendar.numberOfDaysInChangeoverYear == 355)

		#expect(try JulianGregorianCalendar.dayOfYearFrom(year: 1582, month: 1, day: 1) == 1)
		#expect(try JulianGregorianCalendar.dayOfYearFrom(year: 1582, month: 10, day: 4) == 277)
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dayOfYearFrom(year: 1582, month: 10, day: 10) }
		#expect(try JulianGregorianCalendar.dayOfYearFrom(year: 1582, month: 10, day: 15) == 278)
		#expect(try JulianGregorianCalendar.dayOfYearFrom(year: 1582, month: 12, day: 31) == 355)
	}

	@Test func changeoverConstants() throws {
		let first = JulianGregorianCalendar.firstGregorianCalendarDate
		let last = JulianGregorianCalendar.lastJulianCalendarDate

		// The changeover dates themselves
		#expect(first == (1582, 10, 15))
		#expect(last == (1582, 10, 4))

		// October 15, 1582 (Gregorian) immediately follows October 4, 1582 (Julian)
		let firstGregorianJDN = try GregorianCalendar.julianDayNumberFromDate(first)
		#expect(GregorianCalendar.papalReform == firstGregorianJDN)
		#expect(try JulianCalendar.julianDayNumberFromDate(last) + 1 == firstGregorianJDN)

		// The changeover year runs from January 1, 1582 (Julian) up to January 1, 1583 (Gregorian)
		let startOf1582 = try JulianCalendar.julianDayNumberFrom(year: 1582, month: 1, day: 1)
		let startOf1583 = try GregorianCalendar.julianDayNumberFrom(year: 1583, month: 1, day: 1)
		#expect(JulianGregorianCalendar.firstDayOfChangeoverYear == startOf1582)
		#expect(JulianGregorianCalendar.numberOfDaysInChangeoverYear == startOf1583 - startOf1582)
		#expect(JulianGregorianCalendar.changeoverYear == startOf1582 ..< startOf1583)

		// October 1582 runs from October 1 (Julian) up to November 1 (Gregorian)
		let startOfOctober = try JulianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 1)
		let startOfNovember = try GregorianCalendar.julianDayNumberFrom(year: 1582, month: 11, day: 1)
		#expect(JulianGregorianCalendar.numberOfDaysInChangeoverMonth == startOfNovember - startOfOctober)

		// JulianGregorianCalendar.isLeapYear relies on 1582 being a common year in both calendars
		#expect(!JulianCalendar.isLeapYear(1582))
		#expect(!GregorianCalendar.isLeapYear(1582))

		// The Julian calendar took effect on January 1, 45 BCE (year -44)
		#expect(JulianCalendar.effective == (try JulianCalendar.julianDayNumberFrom(year: -44, month: 1, day: 1)))
	}
	
	@Test func decimalYear() throws {
		for Y in [1500, 1581, 1582, 1583, 1600, 1700] {
			for N in 1...JulianGregorianCalendar.numberOfDaysInYear(Y) {
				let date = try JulianGregorianCalendar.dateFrom(year: Y, dayOfYear: N)
				let y = try JulianGregorianCalendar.decimalYearFrom(year: date.year, month: date.month, day: date.day)
				#expect(try JulianGregorianCalendar.dateFromDecimalYear(y) == date)
			}
		}
		#expect(try JulianGregorianCalendar.dateFromDecimalYear(1582 + 276.0 / 355) == (1582, 10, 4))
		#expect(try JulianGregorianCalendar.dateFromDecimalYear(1582 + 277.0 / 355) == (1582, 10, 15))
	}

	@Test func easter() {
		// Dates from Meeus (1998)
		#expect(JulianGregorianCalendar.easter(year: 1991) == (3, 31))
		#expect(JulianGregorianCalendar.easter(year: 1992) == (4, 19))
		#expect(JulianGregorianCalendar.easter(year: 1993) == (4, 11))
		#expect(JulianGregorianCalendar.easter(year: 1954) == (4, 18))
		#expect(JulianGregorianCalendar.easter(year: 2000) == (4, 23))
		#expect(JulianGregorianCalendar.easter(year: 1818) == (3, 22))
		#expect(JulianGregorianCalendar.easter(year: 179) == (4, 12))
		#expect(JulianGregorianCalendar.easter(year: 711) == (4, 12))
		#expect(JulianGregorianCalendar.easter(year: 1243) == (4, 12))
	}

	@Test func julianDayNumber() throws {
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: -999999, month: 1, day: 1) == -363528576)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: -99999, month: 1, day: 1) == -34803576)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: -9999, month: 1, day: 1) == -1931076)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 9999, month: 12, day: 31) == 5373484)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 99999, month: 12, day: 31) == 38245309)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 999999, month: 12, day: 31) == 366963559)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: -4712, month: 1, day: 1) == 0)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 4) == 2299160)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 15) == 2299161)
		// NASA (https://ssd.jpl.nasa.gov/tools/jdc/) uses the Gregorian calendar for dates after 1582-10-04.
		// This means that 1582-10-05 through 1582-10-14 are 10 JDN earlier than if the Julian calendar is used.
		// JulianGregorianCalendar uses a different rule and uses the Julian calendar for dates before 1582-10-15.
		// I'm not sure why but who wants to argue with NASA?
//		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 7) == 2299153)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 2000, month: 1, day: 1) == 2451545)
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: -5000, month: 1, day: 1) == -105192)

		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(-363528576) == (-999999, 1, 1))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(-34803576) == (-99999, 1, 1))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(-1931076) == (-9999, 1, 1))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(5373484) == (9999, 12, 31))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(38245309) == (99999, 12, 31))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(366963559) == (999999, 12, 31))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(0) == (-4712, 1, 1))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(2299160) == (1582, 10, 4))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(2299161) == (1582, 10, 15))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(2451545) == (2000, 1, 1))
		#expect(JulianGregorianCalendar.dateFromJulianDayNumber(-105192) == (-5000, 1, 1))

		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: -9999, month: 1, day: 1) == JulianCalendar.julianDayNumberFrom(year: -9999, month: 1, day: 1))
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 99999, month: 12, day: 31) != JulianCalendar.julianDayNumberFrom(year: 99999, month: 12, day: 31))
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: -4712, month: 1, day: 1) == JulianCalendar.julianDayNumberFrom(year: -4712, month: 1, day: 1))
		#expect(try JulianGregorianCalendar.julianDayNumberFrom(year: 2000, month: 1, day: 1) != JulianCalendar.julianDayNumberFrom(year: 2000, month: 1, day: 1))
	}

	@Test func limits() throws {
		let minDate = JulianGregorianCalendar.dateFromJulianDayNumber(.min)
		let minJ = try JulianGregorianCalendar.julianDayNumberFromDate(minDate)
		#expect(minJ == .min)

		let maxDate = JulianGregorianCalendar.dateFromJulianDayNumber(.max)
		let maxJ = try JulianGregorianCalendar.julianDayNumberFromDate(maxDate)
		#expect(maxJ == .max)

		_ = JulianGregorianCalendar.isLeapYear(.min)
		_ = JulianGregorianCalendar.isLeapYear(.max)

		_ = JulianGregorianCalendar.dayOfWeek(.min)
		_ = JulianGregorianCalendar.dayOfWeek(.max)
	}
}
