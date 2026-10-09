//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct JulianCalendarTests {
	@Test func epoch() throws {
		#expect(try JulianCalendar.julianDayNumberFrom(year: 1, month: 1, day: 1) == JulianCalendar.epoch)
		#expect(JulianCalendar.dateFromJulianDayNumber(JulianCalendar.epoch) == (1, 1, 1))
	}

	@Test func constants() throws {
		#expect(try JulianCalendar.julianDayNumberFrom(year: 0, month: 3, day: 1) == 1_721_118)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 0, month: 2, day: 29) == 1_721_117)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 1, month: 1, day: 1) == 1_721_424)
		#expect(try JulianCalendar.julianDayNumberFrom(year: -4712, month: 1, day: 1) == 0)
	}

	@Test func normalize() throws {
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: 13, day: 1) == (2001, 1, 1))
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: 0, day: 1) == (1999, 12, 1))
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: 1, day: 32) == (2000, 2, 1))
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: 1, day: 0) == (1999, 12, 31))
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: 3, day: 0) == (2000, 2, 29))
		#expect(try JulianCalendar.normalizedDateFrom(year: 1999, month: 3, day: 0) == (1999, 2, 28))
	}

	@Test func dateValidation() {
		#expect(JulianCalendar.isValid(year: 1600, month: 2, day: 29))
		#expect(JulianCalendar.isValid(year: 1700, month: 2, day: 29))
	}

	@Test func leapYear() throws {
		#expect(!JulianCalendar.isLeapYear(1))
		#expect(JulianCalendar.isLeapYear(4))
		#expect(JulianCalendar.isLeapYear(100))
		#expect(!JulianCalendar.isLeapYear(750))
		#expect(JulianCalendar.isLeapYear(900))
		#expect(JulianCalendar.isLeapYear(1236))
		#expect(!JulianCalendar.isLeapYear(1429))
		#expect(JulianCalendar.isLeapYear(1700))
		#expect(!JulianCalendar.isLeapYear(-3))
		#expect(JulianCalendar.isLeapYear(-4))
		#expect(JulianCalendar.isLeapYear(-8))
		#expect(JulianCalendar.isLeapYear(-100))

		for y in -500...1752 {
			let isLeap = JulianCalendar.isLeapYear(y)
			let j = try JulianCalendar.julianDayNumberFrom(year: y, month: 2, day: isLeap ? 29 : 28)
			let d = JulianCalendar.dateFromJulianDayNumber(j)
			#expect(d.month == 2)
			#expect(d.day == (isLeap ? 29 : 28))
		}
	}

	@Test func monthCount() {
		#expect(JulianCalendar.numberOfMonthsInYear == 12)
	}

	@Test func monthLength() throws {
		#expect(try JulianCalendar.numberOfDaysIn(month: 2, year: 1600) == 29)
		#expect(try JulianCalendar.numberOfDaysIn(month: 2, year: 1700) == 29)
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.numberOfDaysIn(month: 0, year: 1000) }
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.numberOfDaysIn(month: 13, year: 1000) }
	}

	@Test func yearLength() {
		#expect(JulianCalendar.numberOfDaysInYear(1) == 365)
		#expect(JulianCalendar.numberOfDaysInYear(4) == 366)
		#expect(JulianCalendar.numberOfDaysInYear(100) == 366)
		#expect(JulianCalendar.numberOfDaysInYear(750) == 365)
		#expect(JulianCalendar.numberOfDaysInYear(900) == 366)
	}

	@Test func dayOfYear() throws {
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 1, day: 1) == 1)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 1, day: 31) == 31)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 2, day: 1) == 32)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 2, day: 28) == 59)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 3, day: 1) == 60)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 3, day: 31) == 90)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 4, day: 1) == 91)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 4, day: 30) == 120)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 5, day: 1) == 121)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 5, day: 31) == 151)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 6, day: 1) == 152)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 6, day: 30) == 181)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 7, day: 1) == 182)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 7, day: 31) == 212)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 8, day: 1) == 213)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 8, day: 31) == 243)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 9, day: 1) == 244)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 9, day: 30) == 273)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 10, day: 1) == 274)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 10, day: 31) == 304)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 11, day: 1) == 305)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 11, day: 30) == 334)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 12, day: 1) == 335)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1901, month: 12, day: 31) == 365)

		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 1) == (1901, 1, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 31) == (1901, 1, 31))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 32) == (1901, 2, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 59) == (1901, 2, 28))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 60) == (1901, 3, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 90) == (1901, 3, 31))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 91) == (1901, 4, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 120) == (1901, 4, 30))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 121) == (1901, 5, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 151) == (1901, 5, 31))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 152) == (1901, 6, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 181) == (1901, 6, 30))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 182) == (1901, 7, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 212) == (1901, 7, 31))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 213) == (1901, 8, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 243) == (1901, 8, 31))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 244) == (1901, 9, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 273) == (1901, 9, 30))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 274) == (1901, 10, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 304) == (1901, 10, 31))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 305) == (1901, 11, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 334) == (1901, 11, 30))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 335) == (1901, 12, 1))
		#expect(try JulianCalendar.dateFrom(year: 1901, dayOfYear: 365) == (1901, 12, 31))

		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 1, day: 1) == 1)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 1, day: 31) == 31)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 2, day: 1) == 32)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 2, day: 29) == 60)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 3, day: 1) == 61)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 3, day: 31) == 91)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 4, day: 1) == 92)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 4, day: 30) == 121)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 5, day: 1) == 122)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 5, day: 31) == 152)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 6, day: 1) == 153)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 6, day: 30) == 182)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 7, day: 1) == 183)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 7, day: 31) == 213)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 8, day: 1) == 214)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 8, day: 31) == 244)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 9, day: 1) == 245)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 9, day: 30) == 274)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 10, day: 1) == 275)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 10, day: 31) == 305)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 11, day: 1) == 306)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 11, day: 30) == 335)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 12, day: 1) == 336)
		#expect(try JulianCalendar.dayOfYearFrom(year: 2000, month: 12, day: 31) == 366)

		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 1) == (2000, 1, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 31) == (2000, 1, 31))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 32) == (2000, 2, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 60) == (2000, 2, 29))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 61) == (2000, 3, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 91) == (2000, 3, 31))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 92) == (2000, 4, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 121) == (2000, 4, 30))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 122) == (2000, 5, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 152) == (2000, 5, 31))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 153) == (2000, 6, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 182) == (2000, 6, 30))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 183) == (2000, 7, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 213) == (2000, 7, 31))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 214) == (2000, 8, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 244) == (2000, 8, 31))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 245) == (2000, 9, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 274) == (2000, 9, 30))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 275) == (2000, 10, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 305) == (2000, 10, 31))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 306) == (2000, 11, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 335) == (2000, 11, 30))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 336) == (2000, 12, 1))
		#expect(try JulianCalendar.dateFrom(year: 2000, dayOfYear: 366) == (2000, 12, 31))
	}

	@Test func dayOfWeek() throws {
		#expect(JulianCalendar.dayOfWeek(JulianCalendar.epoch) == 7)
		#expect(JulianCalendar.dayOfWeek(-9) == 7)
		#expect(JulianCalendar.dayOfWeek(-8) == 1)
		#expect(JulianCalendar.dayOfWeek(-7) == 2)
		#expect(JulianCalendar.dayOfWeek(-6) == 3)
		#expect(JulianCalendar.dayOfWeek(-5) == 4)
		#expect(JulianCalendar.dayOfWeek(-4) == 5)
		#expect(JulianCalendar.dayOfWeek(-3) == 6)
		#expect(JulianCalendar.dayOfWeek(-2) == 7)
		#expect(JulianCalendar.dayOfWeek(-1) == 1)
		#expect(JulianCalendar.dayOfWeek(0) == 2)
		#expect(JulianCalendar.dayOfWeek(1) == 3)
		#expect(JulianCalendar.dayOfWeek(2) == 4)
		#expect(JulianCalendar.dayOfWeek(3) == 5)
		#expect(JulianCalendar.dayOfWeek(4) == 6)
		#expect(JulianCalendar.dayOfWeek(5) == 7)
		#expect(JulianCalendar.dayOfWeek(6) == 1)

		#expect(JulianCalendar.dayOfWeek(try JulianCalendar.julianDayNumberFromDate((-10028, 3, 1))) == JulianCalendar.dayOfWeek(try JulianCalendar.julianDayNumberFromDate((-10000, 3, 1))))
	}

	@Test func easter() {
		// Dates from Meeus (1998)
		#expect(JulianCalendar.easter(year: 179) == (4, 12))
		#expect(JulianCalendar.easter(year: 711) == (4, 12))
		#expect(JulianCalendar.easter(year: 1243) == (4, 12))
	}

	@Test func julianDayNumber() throws {
		#expect(try JulianCalendar.julianDayNumberFrom(year: -999999, month: 1, day: 1) == -363528576)
		#expect(try JulianCalendar.julianDayNumberFrom(year: -99999, month: 1, day: 1) == -34803576)
		#expect(try JulianCalendar.julianDayNumberFrom(year: -9999, month: 1, day: 1) == -1931076)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 9999, month: 12, day: 31) == 5373557)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 99999, month: 12, day: 31) == 38246057)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 999999, month: 12, day: 31) == 366971057)
		#expect(try JulianCalendar.julianDayNumberFrom(year: -4713, month: 12, day: 31) == -1)
		#expect(try JulianCalendar.julianDayNumberFrom(year: -4712, month: 1, day: 1) == 0)
		#expect(try JulianCalendar.julianDayNumberFrom(year: -4712, month: 1, day: 2) == 1)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 4) == 2299160)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 15) == 2299171)
		#expect(try JulianCalendar.julianDayNumberFrom(year: 2000, month: 1, day: 1) == 2451558)
		#expect(try JulianCalendar.julianDayNumberFrom(year: -5000, month: 1, day: 1) == -105192)

		#expect(JulianCalendar.dateFromJulianDayNumber(-363528576) == (-999999, 1, 1))
		#expect(JulianCalendar.dateFromJulianDayNumber(-34803576) == (-99999, 1, 1))
		#expect(JulianCalendar.dateFromJulianDayNumber(-1931076) == (-9999, 1, 1))
		#expect(JulianCalendar.dateFromJulianDayNumber(5373557) == (9999, 12, 31))
		#expect(JulianCalendar.dateFromJulianDayNumber(38246057) == (99999, 12, 31))
		#expect(JulianCalendar.dateFromJulianDayNumber(366971057) == (999999, 12, 31))
		#expect(JulianCalendar.dateFromJulianDayNumber(-1) == (-4713, 12, 31))
		#expect(JulianCalendar.dateFromJulianDayNumber(0) == (-4712, 1, 1))
		#expect(JulianCalendar.dateFromJulianDayNumber(1) == (-4712, 1, 2))
		#expect(JulianCalendar.dateFromJulianDayNumber(2299160) == (1582, 10, 4))
		#expect(JulianCalendar.dateFromJulianDayNumber(2299171) == (1582, 10, 15))
		#expect(JulianCalendar.dateFromJulianDayNumber(2451558) == (2000, 1, 1))
		#expect(JulianCalendar.dateFromJulianDayNumber(-105192) == (-5000, 1, 1))
	}

	@Test func range() throws {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumberFrom(year: .min, month: 1, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumberFrom(year: .max, month: 1, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumberFrom(year: 1, month: .min, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumberFrom(year: 1, month: .max, day: 1)
		}
	}

	@Test func limits() throws {
		let minDate = JulianCalendar.dateFromJulianDayNumber(.min)
		let minJ = try JulianCalendar.julianDayNumberFromDate(minDate)
		#expect(minJ == .min)

		let maxDate = JulianCalendar.dateFromJulianDayNumber(.max)
		let maxJ = try JulianCalendar.julianDayNumberFromDate(maxDate)
		#expect(maxJ == .max)

		_ = JulianCalendar.isLeapYear(.min)
		_ = JulianCalendar.isLeapYear(.max)

		_ = JulianCalendar.dayOfWeek(.min)
		_ = JulianCalendar.dayOfWeek(.max)
	}
}
