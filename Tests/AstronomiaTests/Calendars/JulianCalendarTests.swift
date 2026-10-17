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
		#expect(try JulianCalendar.dayOfYearFrom(year: 1500, month: 2, day: 29) == 60)
		#expect(try JulianCalendar.dayOfYearFrom(year: 1700, month: 2, day: 29) == 60)

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

		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.dateFrom(year: 1000, dayOfYear: 0) }
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.dateFrom(year: 1001, dayOfYear: 366) }
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

	@Test func decimalYear() throws {
		for Y in [-45, -44, 1984, 1985] {
			for N in 1...JulianCalendar.numberOfDaysInYear(Y) {
				let date = try JulianCalendar.dateFrom(year: Y, dayOfYear: N)
				let y = try JulianCalendar.decimalYearFrom(year: date.year, month: date.month, day: date.day)
				#expect(try JulianCalendar.dateFromDecimalYear(y) == date)
			}
		}
		#expect(try JulianCalendar.dateFromDecimalYear(-0x1p-53) == (-1, 12, 31))
		#expect(try JulianCalendar.dateFromDecimalYear(-0x1p-54) == (-1, 12, 31))
		#expect(try JulianCalendar.dateFromDecimalYear(-1e-20) == (-1, 12, 31))
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

	@Test func normalizeAcrossYears() throws {
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: 25, day: 1) == (2002, 1, 1))
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: -12, day: 1) == (1998, 12, 1))
		#expect(try JulianCalendar.normalizedDateFrom(year: 1900, month: 2, day: 29) == (1900, 2, 29))
		#expect(try JulianCalendar.normalizedDateFrom(year: 1900, month: 2, day: 30) == (1900, 3, 1))
		#expect(try JulianCalendar.normalizedDateFrom(year: 2001, month: 1, day: -365) == (2000, 1, 1))
		#expect(try JulianCalendar.normalizedDateFrom(year: 2000, month: 1, day: 1_462) == (2004, 1, 1))
		#expect(try JulianCalendar.normalizedDate((-1, 13, 1)) == (0, 1, 1))

		// Valid dates are unchanged
		for J in stride(from: 1_700_000, through: 1_800_000, by: 13) {
			let date = JulianCalendar.dateFromJulianDayNumber(J)
			#expect(try JulianCalendar.normalizedDate(date) == date)
		}

		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianCalendar.normalizedDateFrom(year: .min, month: 1, day: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianCalendar.normalizedDateFrom(year: 2000, month: 1, day: .max) }
	}

	@Test func invalidDates() {
		#expect(JulianCalendar.isValid(year: -1, month: 2, day: 28))
		#expect(!JulianCalendar.isValid(year: -1, month: 2, day: 29))
		#expect(JulianCalendar.isValid(year: -4, month: 2, day: 29))
		#expect(JulianCalendar.isValid(year: 1582, month: 10, day: 10))
		#expect(!JulianCalendar.isValid(year: 2001, month: 2, day: 29))
		#expect(!JulianCalendar.isValid(year: 2000, month: 6, day: 31))
		#expect(!JulianCalendar.isValid(year: 2000, month: 0, day: 1))
		#expect(!JulianCalendar.isValid(year: 2000, month: 13, day: 1))
		#expect(!JulianCalendar.isValid(year: 2000, month: 1, day: 0))
		#expect(!JulianCalendar.isValidDate((2000, 1, 32)))
	}

	@Test func proleptic() throws {
		#expect(JulianCalendar.isProleptic(1_704_986))
		#expect(!JulianCalendar.isProleptic(1_704_987))
		#expect(JulianCalendar.isProleptic(try JulianCalendar.julianDayNumberFrom(year: -45, month: 12, day: 31)))
		#expect(!JulianCalendar.isProleptic(try JulianCalendar.julianDayNumberFrom(year: -44, month: 1, day: 1)))
		#expect(JulianCalendar.isProleptic(.min))
		#expect(!JulianCalendar.isProleptic(.max))
	}

	@Test func dayOfWeekOfKnownDates() throws {
		// Thursday, October 4, 1582
		#expect(JulianCalendar.dayOfWeek(try JulianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 4)) == 5)
		// Friday, January 1, 45 BCE
		#expect(JulianCalendar.dayOfWeek(try JulianCalendar.julianDayNumberFrom(year: -44, month: 1, day: 1)) == 6)
		// Saturday, December 19, 1999 (January 1, 2000 in the Gregorian calendar)
		#expect(JulianCalendar.dayOfWeek(try JulianCalendar.julianDayNumberFrom(year: 1999, month: 12, day: 19)) == 7)

		// The day of the week repeats every 28 years
		for J in stride(from: 2_000_000, through: 2_001_000, by: 1) {
			#expect(JulianCalendar.dayOfWeek(J) == JulianCalendar.dayOfWeek(J + 28 * 1_461 / 4))
		}
	}

	@Test func dayOfYearFromJulianDayNumber() throws {
		for (Y, daysInYear) in [(-5, 365), (-4, 366), (1900, 366), (1901, 365)] {
			let jan1 = try JulianCalendar.julianDayNumberFrom(year: Y, month: 1, day: 1)
			for N in 1 ... daysInYear {
				#expect(JulianCalendar.dayOfYearFromJulianDayNumber(jan1 + N - 1) == N)
				#expect(try JulianCalendar.dateFrom(year: Y, dayOfYear: N) == JulianCalendar.dateFromJulianDayNumber(jan1 + N - 1))
			}
			#expect(JulianCalendar.dayOfYearFromJulianDayNumber(jan1 + daysInYear) == 1)
		}
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.dayOfYearFrom(year: 1901, month: 2, day: 29) }
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.dayOfYearFrom(year: 1901, month: 0, day: 1) }
	}

	@Test func decimalYearFromJulianDayNumber() throws {
		#expect(JulianCalendar.decimalYearFromJulianDayNumber(0) == -4712)
		#expect(JulianCalendar.decimalYearFromJulianDayNumber(JulianCalendar.epoch) == 1)
		#expect(try JulianCalendar.decimalYearFrom(year: 1900, month: 7, day: 2) == 1900.5)
		#expect(try JulianCalendar.dateFromDecimalYear(1900.5) == (1900, 7, 2))
		#expect(try JulianCalendar.dateFromDecimalYear(-0.5) == (-1, 7, 2))
		#expect(try JulianCalendar.julianDayNumberFromDecimalYear(1) == JulianCalendar.epoch)

		var previous = -Double.infinity
		var failures: [JulianDayNumber] = []
		for J in stride(from: -2_000_000, through: 4_000_000, by: 97) {
			let decimalYear = JulianCalendar.decimalYearFromJulianDayNumber(J)
			if try decimalYear <= previous || JulianCalendar.julianDayNumberFromDecimalYear(decimalYear) != J {
				failures.append(J)
			}
			previous = decimalYear
		}
		#expect(failures.isEmpty)

		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.decimalYearFrom(year: 1901, month: 2, day: 29) }
		#expect(throws: CalendarError.nonFiniteValue) { try JulianCalendar.dateFromDecimalYear(-.infinity) }
		#expect(throws: CalendarError.invalidDecimalYear) { try JulianCalendar.dateFromDecimalYear(-1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianCalendar.julianDayNumberFromDecimalYear(1e18) }
	}

	@Test func easterDates() {
		#expect(JulianCalendar.easter(year: 325) == (4, 18))
		#expect(JulianCalendar.easter(year: 1066) == (4, 16))
		#expect(JulianCalendar.easter(year: 1582) == (4, 15))
		// Orthodox Easter 2026 was April 12 in the Gregorian calendar
		#expect(JulianCalendar.easter(year: 2026) == (3, 30))
	}

	@Test func easterIsASundayBetweenMarch22AndApril25() throws {
		var failures: [Int] = []
		for Y in -3000 ... 5000 {
			let (M, D) = JulianCalendar.easter(year: Y)
			let J = try JulianCalendar.julianDayNumberFrom(year: Y, month: M, day: D)
			if JulianCalendar.dayOfWeek(J) != 1 || (M, D) < (3, 22) || (M, D) > (4, 25) {
				failures.append(Y)
			}
		}
		#expect(failures.isEmpty)
	}

	@Test func easterPeriodicity() {
		for Y in -600 ... 600 {
			#expect(JulianCalendar.easter(year: Y) == JulianCalendar.easter(year: Y + 532))
		}
		#expect(JulianCalendar.easter(year: .max) == JulianCalendar.easter(year: Int.max % 532))
		_ = JulianCalendar.easter(year: .min)
	}

	@Test func julianDayNumberRoundTrip() throws {
		var failures: [JulianDayNumber] = []
		for J in stride(from: -2_000_000, through: 6_000_000, by: 29) {
			let date = JulianCalendar.dateFromJulianDayNumber(J)
			if try !JulianCalendar.isValidDate(date) || JulianCalendar.julianDayNumberFromDate(date) != J {
				failures.append(J)
			}
		}
		#expect(failures.isEmpty)
	}

	@Test func agreesWithMeeus() throws {
		var failures: [YearMonthDay] = []
		for Y in stride(from: -4000, through: 4000, by: 3) {
			for M in 1 ... 12 {
				for D in [1, 15, 28] {
					let expected = meeusJulianDayNumber(year: Y, month: M, day: D)
					if try JulianCalendar.julianDayNumberFrom(year: Y, month: M, day: D) != expected || JulianCalendar.dateFromJulianDayNumber(expected) != (Y, M, D) {
						failures.append((Y, M, D))
					}
				}
			}
		}
		#expect(failures.isEmpty)
	}
}

private func floorDivide(_ a: Int, _ b: Int) -> Int {
	let (q, r) = a.quotientAndRemainder(dividingBy: b)
	return r < 0 ? q - 1 : q
}

/// The Julian day number of a proleptic Julian date using the algorithm in chapter 7 of
/// Meeus, *Astronomical Algorithms*, 2nd ed. (1998), in integer arithmetic. Valid for years
/// after -4716.
private func meeusJulianDayNumber(year: Int, month: Int, day: Int) -> JulianDayNumber {
	let (Y, M) = month > 2 ? (year, month) : (year - 1, month + 12)
	return floorDivide(1_461 * (Y + 4_716), 4) + (306_001 * (M + 1)) / 10_000 + day - 1_524
}
