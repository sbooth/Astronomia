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
		#expect(try JulianCalendar.julianDayNumber(year: 1, month: 1, day: 1) == JulianCalendar.epoch)
		#expect(JulianCalendar.date(julianDayNumber: JulianCalendar.epoch) == (1, 1, 1))
	}

	@Test func constants() throws {
		#expect(try JulianCalendar.julianDayNumber(year: 0, month: 3, day: 1) == 1_721_118)
		#expect(try JulianCalendar.julianDayNumber(year: 0, month: 2, day: 29) == 1_721_117)
		#expect(try JulianCalendar.julianDayNumber(year: 1, month: 1, day: 1) == 1_721_424)
		#expect(try JulianCalendar.julianDayNumber(year: -4712, month: 1, day: 1) == 0)
	}

	@Test func normalize() throws {
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: 13, day: 1) == (2001, 1, 1))
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: 0, day: 1) == (1999, 12, 1))
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: 1, day: 32) == (2000, 2, 1))
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: 1, day: 0) == (1999, 12, 31))
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: 3, day: 0) == (2000, 2, 29))
		#expect(try JulianCalendar.normalizedDate(year: 1999, month: 3, day: 0) == (1999, 2, 28))
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
			let j = try JulianCalendar.julianDayNumber(year: y, month: 2, day: isLeap ? 29 : 28)
			let d = JulianCalendar.date(julianDayNumber: j)
			#expect(d.month == 2)
			#expect(d.day == (isLeap ? 29 : 28))
		}
	}

	@Test func monthCount() {
		#expect(JulianCalendar.numberOfMonthsInYear == 12)
	}

	@Test func monthLength() throws {
		#expect(try JulianCalendar.numberOfDays(inMonth: 2, year: 1600) == 29)
		#expect(try JulianCalendar.numberOfDays(inMonth: 2, year: 1700) == 29)
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.numberOfDays(inMonth: 0, year: 1000) }
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.numberOfDays(inMonth: 13, year: 1000) }
	}

	@Test func yearLength() {
		#expect(JulianCalendar.numberOfDays(inYear:1) == 365)
		#expect(JulianCalendar.numberOfDays(inYear:4) == 366)
		#expect(JulianCalendar.numberOfDays(inYear:100) == 366)
		#expect(JulianCalendar.numberOfDays(inYear:750) == 365)
		#expect(JulianCalendar.numberOfDays(inYear:900) == 366)
	}

	@Test func dayOfYear() throws {
		#expect(try JulianCalendar.dayOfYear(year: 1500, month: 2, day: 29) == 60)
		#expect(try JulianCalendar.dayOfYear(year: 1700, month: 2, day: 29) == 60)

		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 1, day: 1) == 1)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 1, day: 31) == 31)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 2, day: 1) == 32)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 2, day: 28) == 59)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 3, day: 1) == 60)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 3, day: 31) == 90)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 4, day: 1) == 91)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 4, day: 30) == 120)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 5, day: 1) == 121)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 5, day: 31) == 151)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 6, day: 1) == 152)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 6, day: 30) == 181)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 7, day: 1) == 182)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 7, day: 31) == 212)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 8, day: 1) == 213)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 8, day: 31) == 243)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 9, day: 1) == 244)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 9, day: 30) == 273)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 10, day: 1) == 274)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 10, day: 31) == 304)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 11, day: 1) == 305)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 11, day: 30) == 334)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 12, day: 1) == 335)
		#expect(try JulianCalendar.dayOfYear(year: 1901, month: 12, day: 31) == 365)

		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 1) == (1901, 1, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 31) == (1901, 1, 31))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 32) == (1901, 2, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 59) == (1901, 2, 28))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 60) == (1901, 3, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 90) == (1901, 3, 31))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 91) == (1901, 4, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 120) == (1901, 4, 30))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 121) == (1901, 5, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 151) == (1901, 5, 31))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 152) == (1901, 6, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 181) == (1901, 6, 30))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 182) == (1901, 7, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 212) == (1901, 7, 31))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 213) == (1901, 8, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 243) == (1901, 8, 31))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 244) == (1901, 9, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 273) == (1901, 9, 30))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 274) == (1901, 10, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 304) == (1901, 10, 31))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 305) == (1901, 11, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 334) == (1901, 11, 30))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 335) == (1901, 12, 1))
		#expect(try JulianCalendar.date(year: 1901, dayOfYear: 365) == (1901, 12, 31))

		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 1, day: 1) == 1)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 1, day: 31) == 31)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 2, day: 1) == 32)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 2, day: 29) == 60)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 3, day: 1) == 61)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 3, day: 31) == 91)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 4, day: 1) == 92)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 4, day: 30) == 121)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 5, day: 1) == 122)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 5, day: 31) == 152)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 6, day: 1) == 153)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 6, day: 30) == 182)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 7, day: 1) == 183)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 7, day: 31) == 213)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 8, day: 1) == 214)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 8, day: 31) == 244)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 9, day: 1) == 245)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 9, day: 30) == 274)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 10, day: 1) == 275)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 10, day: 31) == 305)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 11, day: 1) == 306)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 11, day: 30) == 335)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 12, day: 1) == 336)
		#expect(try JulianCalendar.dayOfYear(year: 2000, month: 12, day: 31) == 366)

		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 1) == (2000, 1, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 31) == (2000, 1, 31))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 32) == (2000, 2, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 60) == (2000, 2, 29))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 61) == (2000, 3, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 91) == (2000, 3, 31))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 92) == (2000, 4, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 121) == (2000, 4, 30))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 122) == (2000, 5, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 152) == (2000, 5, 31))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 153) == (2000, 6, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 182) == (2000, 6, 30))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 183) == (2000, 7, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 213) == (2000, 7, 31))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 214) == (2000, 8, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 244) == (2000, 8, 31))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 245) == (2000, 9, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 274) == (2000, 9, 30))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 275) == (2000, 10, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 305) == (2000, 10, 31))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 306) == (2000, 11, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 335) == (2000, 11, 30))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 336) == (2000, 12, 1))
		#expect(try JulianCalendar.date(year: 2000, dayOfYear: 366) == (2000, 12, 31))

		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.date(year: 1000, dayOfYear: 0) }
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.date(year: 1001, dayOfYear: 366) }
	}

	@Test func dayOfWeek() throws {
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: JulianCalendar.epoch) == 7)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -9) == 7)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -8) == 1)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -7) == 2)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -6) == 3)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -5) == 4)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -4) == 5)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -3) == 6)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -2) == 7)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: -1) == 1)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: 0) == 2)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: 1) == 3)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: 2) == 4)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: 3) == 5)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: 4) == 6)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: 5) == 7)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: 6) == 1)

		#expect(JulianCalendar.dayOfWeek(julianDayNumber: try JulianCalendar.julianDayNumber(for: (-10028, 3, 1))) == JulianCalendar.dayOfWeek(julianDayNumber: try JulianCalendar.julianDayNumber(for: (-10000, 3, 1))))
	}

	@Test func decimalYear() throws {
		for Y in [-45, -44, 1984, 1985] {
			for N in 1...JulianCalendar.numberOfDays(inYear:Y) {
				let date = try JulianCalendar.date(year: Y, dayOfYear: N)
				let y = try JulianCalendar.decimalYear(year: date.year, month: date.month, day: date.day)
				#expect(try JulianCalendar.date(decimalYear: y) == date)
			}
		}
		#expect(try JulianCalendar.date(decimalYear: -0x1p-53) == (-1, 12, 31))
		#expect(try JulianCalendar.date(decimalYear: -0x1p-54) == (-1, 12, 31))
		#expect(try JulianCalendar.date(decimalYear: -1e-20) == (-1, 12, 31))
	}

	@Test func easter() {
		// Dates from Meeus (1998)
		#expect(JulianCalendar.easter(year: 179) == (4, 12))
		#expect(JulianCalendar.easter(year: 711) == (4, 12))
		#expect(JulianCalendar.easter(year: 1243) == (4, 12))
	}

	@Test func julianDayNumber() throws {
		#expect(try JulianCalendar.julianDayNumber(year: -999999, month: 1, day: 1) == -363528576)
		#expect(try JulianCalendar.julianDayNumber(year: -99999, month: 1, day: 1) == -34803576)
		#expect(try JulianCalendar.julianDayNumber(year: -9999, month: 1, day: 1) == -1931076)
		#expect(try JulianCalendar.julianDayNumber(year: 9999, month: 12, day: 31) == 5373557)
		#expect(try JulianCalendar.julianDayNumber(year: 99999, month: 12, day: 31) == 38246057)
		#expect(try JulianCalendar.julianDayNumber(year: 999999, month: 12, day: 31) == 366971057)
		#expect(try JulianCalendar.julianDayNumber(year: -4713, month: 12, day: 31) == -1)
		#expect(try JulianCalendar.julianDayNumber(year: -4712, month: 1, day: 1) == 0)
		#expect(try JulianCalendar.julianDayNumber(year: -4712, month: 1, day: 2) == 1)
		#expect(try JulianCalendar.julianDayNumber(year: 1582, month: 10, day: 4) == 2299160)
		#expect(try JulianCalendar.julianDayNumber(year: 1582, month: 10, day: 15) == 2299171)
		#expect(try JulianCalendar.julianDayNumber(year: 2000, month: 1, day: 1) == 2451558)
		#expect(try JulianCalendar.julianDayNumber(year: -5000, month: 1, day: 1) == -105192)

		#expect(JulianCalendar.date(julianDayNumber: -363528576) == (-999999, 1, 1))
		#expect(JulianCalendar.date(julianDayNumber: -34803576) == (-99999, 1, 1))
		#expect(JulianCalendar.date(julianDayNumber: -1931076) == (-9999, 1, 1))
		#expect(JulianCalendar.date(julianDayNumber: 5373557) == (9999, 12, 31))
		#expect(JulianCalendar.date(julianDayNumber: 38246057) == (99999, 12, 31))
		#expect(JulianCalendar.date(julianDayNumber: 366971057) == (999999, 12, 31))
		#expect(JulianCalendar.date(julianDayNumber: -1) == (-4713, 12, 31))
		#expect(JulianCalendar.date(julianDayNumber: 0) == (-4712, 1, 1))
		#expect(JulianCalendar.date(julianDayNumber: 1) == (-4712, 1, 2))
		#expect(JulianCalendar.date(julianDayNumber: 2299160) == (1582, 10, 4))
		#expect(JulianCalendar.date(julianDayNumber: 2299171) == (1582, 10, 15))
		#expect(JulianCalendar.date(julianDayNumber: 2451558) == (2000, 1, 1))
		#expect(JulianCalendar.date(julianDayNumber: -105192) == (-5000, 1, 1))
	}

	@Test func range() throws {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumber(year: .min, month: 1, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumber(year: .max, month: 1, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumber(year: 1, month: .min, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try JulianCalendar.julianDayNumber(year: 1, month: .max, day: 1)
		}
	}

	@Test func limits() throws {
		let minDate = JulianCalendar.date(julianDayNumber: .min)
		let minJ = try JulianCalendar.julianDayNumber(for: minDate)
		#expect(minJ == .min)

		let maxDate = JulianCalendar.date(julianDayNumber: .max)
		let maxJ = try JulianCalendar.julianDayNumber(for: maxDate)
		#expect(maxJ == .max)

		_ = JulianCalendar.isLeapYear(.min)
		_ = JulianCalendar.isLeapYear(.max)

		_ = JulianCalendar.dayOfWeek(julianDayNumber: .min)
		_ = JulianCalendar.dayOfWeek(julianDayNumber: .max)
	}

	@Test func normalizeAcrossYears() throws {
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: 25, day: 1) == (2002, 1, 1))
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: -12, day: 1) == (1998, 12, 1))
		#expect(try JulianCalendar.normalizedDate(year: 1900, month: 2, day: 29) == (1900, 2, 29))
		#expect(try JulianCalendar.normalizedDate(year: 1900, month: 2, day: 30) == (1900, 3, 1))
		#expect(try JulianCalendar.normalizedDate(year: 2001, month: 1, day: -365) == (2000, 1, 1))
		#expect(try JulianCalendar.normalizedDate(year: 2000, month: 1, day: 1_462) == (2004, 1, 1))
		#expect(try JulianCalendar.normalizedDate((-1, 13, 1)) == (0, 1, 1))

		// Valid dates are unchanged
		for J in stride(from: 1_700_000, through: 1_800_000, by: 13) {
			let date = JulianCalendar.date(julianDayNumber: J)
			#expect(try JulianCalendar.normalizedDate(date) == date)
		}

		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianCalendar.normalizedDate(year: .min, month: 1, day: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianCalendar.normalizedDate(year: 2000, month: 1, day: .max) }
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
		#expect(!JulianCalendar.isValid((2000, 1, 32)))
	}

	@Test func proleptic() throws {
		#expect(JulianCalendar.isProleptic(julianDayNumber: 1_704_986))
		#expect(!JulianCalendar.isProleptic(julianDayNumber: 1_704_987))
		#expect(JulianCalendar.isProleptic(julianDayNumber: try JulianCalendar.julianDayNumber(year: -45, month: 12, day: 31)))
		#expect(!JulianCalendar.isProleptic(julianDayNumber: try JulianCalendar.julianDayNumber(year: -44, month: 1, day: 1)))
		#expect(JulianCalendar.isProleptic(julianDayNumber: .min))
		#expect(!JulianCalendar.isProleptic(julianDayNumber: .max))
	}

	@Test func dayOfWeekOfKnownDates() throws {
		// Thursday, October 4, 1582
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: try JulianCalendar.julianDayNumber(year: 1582, month: 10, day: 4)) == 5)
		// Friday, January 1, 45 BCE
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: try JulianCalendar.julianDayNumber(year: -44, month: 1, day: 1)) == 6)
		// Saturday, December 19, 1999 (January 1, 2000 in the Gregorian calendar)
		#expect(JulianCalendar.dayOfWeek(julianDayNumber: try JulianCalendar.julianDayNumber(year: 1999, month: 12, day: 19)) == 7)

		// The day of the week repeats every 28 years
		for J in stride(from: 2_000_000, through: 2_001_000, by: 1) {
			#expect(JulianCalendar.dayOfWeek(julianDayNumber: J) == JulianCalendar.dayOfWeek(julianDayNumber: J + 28 * 1_461 / 4))
		}
	}

	@Test func dayOfYearFromJulianDayNumber() throws {
		for (Y, daysInYear) in [(-5, 365), (-4, 366), (1900, 366), (1901, 365)] {
			let jan1 = try JulianCalendar.julianDayNumber(year: Y, month: 1, day: 1)
			for N in 1 ... daysInYear {
				#expect(JulianCalendar.dayOfYear(julianDayNumber: jan1 + N - 1) == N)
				#expect(try JulianCalendar.date(year: Y, dayOfYear: N) == JulianCalendar.date(julianDayNumber: jan1 + N - 1))
			}
			#expect(JulianCalendar.dayOfYear(julianDayNumber: jan1 + daysInYear) == 1)
		}
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.dayOfYear(year: 1901, month: 2, day: 29) }
		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.dayOfYear(year: 1901, month: 0, day: 1) }
	}

	@Test func decimalYearFromJulianDayNumber() throws {
		#expect(JulianCalendar.decimalYear(julianDayNumber: 0) == -4712)
		#expect(JulianCalendar.decimalYear(julianDayNumber: JulianCalendar.epoch) == 1)
		#expect(try JulianCalendar.decimalYear(year: 1900, month: 7, day: 2) == 1900.5)
		#expect(try JulianCalendar.date(decimalYear: 1900.5) == (1900, 7, 2))
		#expect(try JulianCalendar.date(decimalYear: -0.5) == (-1, 7, 2))
		#expect(try JulianCalendar.julianDayNumber(decimalYear: 1) == JulianCalendar.epoch)

		var previous = -Double.infinity
		var failures: [JulianDayNumber] = []
		for J in stride(from: -2_000_000, through: 4_000_000, by: 97) {
			let decimalYear = JulianCalendar.decimalYear(julianDayNumber: J)
			if try decimalYear <= previous || JulianCalendar.julianDayNumber(decimalYear: decimalYear) != J {
				failures.append(J)
			}
			previous = decimalYear
		}
		#expect(failures.isEmpty)

		#expect(throws: CalendarError.invalidDate) { try JulianCalendar.decimalYear(year: 1901, month: 2, day: 29) }
		#expect(throws: CalendarError.nonFiniteValue) { try JulianCalendar.date(decimalYear: -.infinity) }
		#expect(throws: CalendarError.invalidDecimalYear) { try JulianCalendar.date(decimalYear: -1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianCalendar.julianDayNumber(decimalYear: 1e18) }
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
			let J = try JulianCalendar.julianDayNumber(year: Y, month: M, day: D)
			if JulianCalendar.dayOfWeek(julianDayNumber: J) != 1 || (M, D) < (3, 22) || (M, D) > (4, 25) {
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
			let date = JulianCalendar.date(julianDayNumber: J)
			if try !JulianCalendar.isValid(date) || JulianCalendar.julianDayNumber(for: date) != J {
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
					if try JulianCalendar.julianDayNumber(year: Y, month: M, day: D) != expected || JulianCalendar.date(julianDayNumber: expected) != (Y, M, D) {
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
