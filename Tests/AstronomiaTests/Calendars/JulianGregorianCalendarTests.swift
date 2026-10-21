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
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 1, month: 1, day: 1) == JulianGregorianCalendar.epoch)
		#expect(JulianGregorianCalendar.date(julianDayNumber: JulianGregorianCalendar.epoch) == (1, 1, 1))
	}

	@Test func dateValidation() {
		#expect(JulianGregorianCalendar.isValid(year: 1969, month: 7, day: 20))
		#expect(!JulianGregorianCalendar.isValid(year: 1969, month: 7, day: 40))
		#expect(JulianGregorianCalendar.isValid(year: 1600, month: 2, day: 29))
		#expect(!JulianGregorianCalendar.isValid((1582, 10, 10)))
	}

	@Test func leapYear() throws {
		#expect(JulianGregorianCalendar.isLeapYear(900))
		#expect(!JulianGregorianCalendar.isLeapYear(1700))

		for y in -1000...2000 {
			let isLeap = JulianGregorianCalendar.isLeapYear(y)
			let j = try JulianGregorianCalendar.julianDayNumber(year: y, month: 2, day: isLeap ? 29 : 28)
			let d = JulianGregorianCalendar.date(julianDayNumber: j)
			#expect(d.month == 2)
			#expect(d.day == (isLeap ? 29 : 28))
		}
	}

	@Test func monthCount() {
		#expect(JulianGregorianCalendar.numberOfMonthsInYear == 12)
	}

	@Test func monthLength() throws {
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 1, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 2, year: 1900) == 28)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 3, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 4, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 5, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 6, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 7, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 8, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 9, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 10, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 11, year: 1900) == 30)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 12, year: 1900) == 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 2, year: 1600) == 29)
	}

	@Test func dayOfYear() throws {
		#expect(try JulianGregorianCalendar.dayOfYear(year: 1500, month: 2, day: 29) == 60)
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dayOfYear(year: 1700, month: 2, day: 29) }
		#expect(try JulianGregorianCalendar.date(year: 1582, dayOfYear: 277) == (1582, 10, 4))
		#expect(try JulianGregorianCalendar.date(year: 1582, dayOfYear: 278) == (1582, 10, 15))
		#expect(try JulianGregorianCalendar.date(year: 1582, dayOfYear: 355) == (1582, 12, 31))

		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.date(year: 1582, dayOfYear: 0) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.date(year: 1582, dayOfYear: 365) }
	}

	@Test func changeover() throws {
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 10, year: 1582) == 21)
		let oct1 = try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 1)
		let oct31 = try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 31)
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 10, year: 1582) == (oct31 - oct1 + 1))

		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 9, year: 1582) == JulianCalendar.numberOfDays(inMonth: 9, year: 1582))
		#expect(try JulianGregorianCalendar.numberOfDays(inMonth: 11, year: 1582) == GregorianCalendar.numberOfDays(inMonth: 11, year: 1582))

		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 3) == true)
		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 4) == true)
		for day in 5...14 {
			#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: day) == false)
		}
		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 15) == true)
		#expect(JulianGregorianCalendar.isValid(year: 1582, month: 10, day: 16) == true)

		#expect(JulianGregorianCalendar.date(julianDayNumber: GregorianCalendar.papalReform) == (1582, 10, 15))
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 15) == GregorianCalendar.papalReform)

		#expect(JulianGregorianCalendar.date(julianDayNumber: GregorianCalendar.papalReform - 1) == (1582, 10, 4))
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 4) == GregorianCalendar.papalReform - 1)

		#expect(JulianGregorianCalendar.numberOfDays(inYear:1582) == 355)
		let jan1 = try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 1, day: 1)
		let dec31 = try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 12, day: 31)
		#expect(JulianGregorianCalendar.numberOfDays(inYear:1582) == (dec31 - jan1 + 1))

		var sum = 0
		for m in 1...12 {
			sum += try JulianGregorianCalendar.numberOfDays(inMonth: m, year: 1582)
		}

		#expect(JulianGregorianCalendar.numberOfDays(inYear:1582) == sum)
		#expect(sum == (dec31 - jan1 + 1))
		#expect(sum == JulianGregorianCalendar.numberOfDaysInChangeoverYear)
		#expect(JulianGregorianCalendar.numberOfDaysInChangeoverYear == 355)

		#expect(try JulianGregorianCalendar.dayOfYear(year: 1582, month: 1, day: 1) == 1)
		#expect(try JulianGregorianCalendar.dayOfYear(year: 1582, month: 10, day: 4) == 277)
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dayOfYear(year: 1582, month: 10, day: 10) }
		#expect(try JulianGregorianCalendar.dayOfYear(year: 1582, month: 10, day: 15) == 278)
		#expect(try JulianGregorianCalendar.dayOfYear(year: 1582, month: 12, day: 31) == 355)
	}

	@Test func changeoverConstants() throws {
		let first = JulianGregorianCalendar.firstGregorianCalendarDate
		let last = JulianGregorianCalendar.lastJulianCalendarDate

		// The changeover dates themselves
		#expect(first == (1582, 10, 15))
		#expect(last == (1582, 10, 4))

		// October 15, 1582 (Gregorian) immediately follows October 4, 1582 (Julian)
		let firstGregorianJDN = try GregorianCalendar.julianDayNumber(for: first)
		#expect(GregorianCalendar.papalReform == firstGregorianJDN)
		#expect(try JulianCalendar.julianDayNumber(for: last) + 1 == firstGregorianJDN)

		// The changeover year runs from January 1, 1582 (Julian) up to January 1, 1583 (Gregorian)
		let startOf1582 = try JulianCalendar.julianDayNumber(year: 1582, month: 1, day: 1)
		let startOf1583 = try GregorianCalendar.julianDayNumber(year: 1583, month: 1, day: 1)
		#expect(JulianGregorianCalendar.firstDayOfChangeoverYear == startOf1582)
		#expect(JulianGregorianCalendar.numberOfDaysInChangeoverYear == startOf1583 - startOf1582)
		#expect(JulianGregorianCalendar.changeoverYear == startOf1582 ..< startOf1583)

		// October 1582 runs from October 1 (Julian) up to November 1 (Gregorian)
		let startOfOctober = try JulianCalendar.julianDayNumber(year: 1582, month: 10, day: 1)
		let startOfNovember = try GregorianCalendar.julianDayNumber(year: 1582, month: 11, day: 1)
		#expect(JulianGregorianCalendar.numberOfDaysInChangeoverMonth == startOfNovember - startOfOctober)

		// JulianGregorianCalendar.isLeapYear relies on 1582 being a common year in both calendars
		#expect(!JulianCalendar.isLeapYear(1582))
		#expect(!GregorianCalendar.isLeapYear(1582))

		// The Julian calendar took effect on January 1, 45 BCE (year -44)
		#expect(JulianCalendar.effective == (try JulianCalendar.julianDayNumber(year: -44, month: 1, day: 1)))
	}
	
	@Test func decimalYear() throws {
		for Y in [1500, 1581, 1582, 1583, 1600, 1700] {
			for N in 1...JulianGregorianCalendar.numberOfDays(inYear:Y) {
				let date = try JulianGregorianCalendar.date(year: Y, dayOfYear: N)
				let y = try JulianGregorianCalendar.decimalYear(year: date.year, month: date.month, day: date.day)
				#expect(try JulianGregorianCalendar.date(decimalYear: y) == date)
			}
		}
		#expect(try JulianGregorianCalendar.date(decimalYear: 1582 + 276.0 / 355) == (1582, 10, 4))
		#expect(try JulianGregorianCalendar.date(decimalYear: 1582 + 277.0 / 355) == (1582, 10, 15))
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
		#expect(try JulianGregorianCalendar.julianDayNumber(year: -999999, month: 1, day: 1) == -363528576)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: -99999, month: 1, day: 1) == -34803576)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: -9999, month: 1, day: 1) == -1931076)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 9999, month: 12, day: 31) == 5373484)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 99999, month: 12, day: 31) == 38245309)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 999999, month: 12, day: 31) == 366963559)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: -4712, month: 1, day: 1) == 0)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 4) == 2299160)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 15) == 2299161)
		// NASA (https://ssd.jpl.nasa.gov/tools/jdc/) uses the Gregorian calendar for dates after
		// 1582-10-04. This means that 1582-10-05 through 1582-10-14 are 10 JDN earlier than if the
		// Julian calendar is used. JulianGregorianCalendar uses a different rule and uses the
		// Julian calendar for dates before 1582-10-15.
		// I'm not sure why but who wants to argue with NASA?
//		#expect(try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 7) == 2299153)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 2000, month: 1, day: 1) == 2451545)
		#expect(try JulianGregorianCalendar.julianDayNumber(year: -5000, month: 1, day: 1) == -105192)

		#expect(JulianGregorianCalendar.date(julianDayNumber: -363528576) == (-999999, 1, 1))
		#expect(JulianGregorianCalendar.date(julianDayNumber: -34803576) == (-99999, 1, 1))
		#expect(JulianGregorianCalendar.date(julianDayNumber: -1931076) == (-9999, 1, 1))
		#expect(JulianGregorianCalendar.date(julianDayNumber: 5373484) == (9999, 12, 31))
		#expect(JulianGregorianCalendar.date(julianDayNumber: 38245309) == (99999, 12, 31))
		#expect(JulianGregorianCalendar.date(julianDayNumber: 366963559) == (999999, 12, 31))
		#expect(JulianGregorianCalendar.date(julianDayNumber: 0) == (-4712, 1, 1))
		#expect(JulianGregorianCalendar.date(julianDayNumber: 2299160) == (1582, 10, 4))
		#expect(JulianGregorianCalendar.date(julianDayNumber: 2299161) == (1582, 10, 15))
		#expect(JulianGregorianCalendar.date(julianDayNumber: 2451545) == (2000, 1, 1))
		#expect(JulianGregorianCalendar.date(julianDayNumber: -105192) == (-5000, 1, 1))

		#expect(try JulianGregorianCalendar.julianDayNumber(year: -9999, month: 1, day: 1) == JulianCalendar.julianDayNumber(year: -9999, month: 1, day: 1))
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 99999, month: 12, day: 31) != JulianCalendar.julianDayNumber(year: 99999, month: 12, day: 31))
		#expect(try JulianGregorianCalendar.julianDayNumber(year: -4712, month: 1, day: 1) == JulianCalendar.julianDayNumber(year: -4712, month: 1, day: 1))
		#expect(try JulianGregorianCalendar.julianDayNumber(year: 2000, month: 1, day: 1) != JulianCalendar.julianDayNumber(year: 2000, month: 1, day: 1))
	}

	@Test func limits() throws {
		let minDate = JulianGregorianCalendar.date(julianDayNumber: .min)
		let minJ = try JulianGregorianCalendar.julianDayNumber(for: minDate)
		#expect(minJ == .min)

		let maxDate = JulianGregorianCalendar.date(julianDayNumber: .max)
		let maxJ = try JulianGregorianCalendar.julianDayNumber(for: maxDate)
		#expect(maxJ == .max)

		_ = JulianGregorianCalendar.isLeapYear(.min)
		_ = JulianGregorianCalendar.isLeapYear(.max)

		_ = JulianGregorianCalendar.dayOfWeek(julianDayNumber: .min)
		_ = JulianGregorianCalendar.dayOfWeek(julianDayNumber: .max)
	}

	@Test func normalize() throws {
		#expect(try JulianGregorianCalendar.normalizedDate(year: 2000, month: 13, day: 1) == (2001, 1, 1))
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1900, month: 2, day: 29) == (1900, 3, 1))
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1500, month: 2, day: 29) == (1500, 2, 29))
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: 10, day: 4) == (1582, 10, 4))
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: 10, day: 15) == (1582, 10, 15))
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: 10, day: 0) == (1582, 9, 30))
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: 10, day: 36) == (1582, 11, 5))
		#expect(try JulianGregorianCalendar.normalizedDate((2000, 14, 30)) == (2001, 3, 2))
		#expect(try JulianGregorianCalendar.normalizedDate((1582, 10, 10)) == (1582, 10, 20))

		// Valid dates are unchanged
		for J in stride(from: 2_290_000, through: 2_310_000, by: 3) {
			let date = JulianGregorianCalendar.date(julianDayNumber: J)
			#expect(try JulianGregorianCalendar.normalizedDate(date) == date)
		}

		// Agrees with the calendar identifier
		for M in -13 ... 26 {
			for D in [-400, -31, -1, 0, 1, 5, 14, 29, 32, 400] {
				#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: M, day: D) == CalendarIdentifier.julianGregorian.normalizedDate(year: 1582, month: M, day: D), "M = \(M), D = \(D)")
			}
		}

		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianGregorianCalendar.normalizedDate(year: .max, month: 12, day: 31) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianGregorianCalendar.normalizedDate(year: .min, month: 1, day: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianGregorianCalendar.normalizedDate((2000, 1, .max)) }
	}

	@Test func normalizeNonexistentDates() throws {
		// October 5-14, 1582 count forward from October 4 in the Julian calendar
		for day in 5 ... 14 {
			#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: 10, day: day) == (1582, 10, day + 10))
			#expect(try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: day) == JulianCalendar.julianDayNumber(year: 1582, month: 10, day: day))
		}

		// The calendar is chosen using the normalized year and month with the unnormalized day
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1581, month: 22, day: 10) == (1582, 10, 20))
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1583, month: -2, day: 1) == (1582, 10, 1))
		// September 45 is counted in the Julian calendar
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: 9, day: 45) == (1582, 10, 25))
		// November -20 is counted back in the Gregorian calendar to Gregorian October 11, which is
		// Julian October 1
		#expect(try JulianGregorianCalendar.normalizedDate(year: 1582, month: 11, day: -20) == (1582, 10, 1))
	}

	@Test func isJulianAndIsProlepticJulian() throws {
		#expect(JulianGregorianCalendar.isJulian(julianDayNumber: 2_299_160))
		#expect(!JulianGregorianCalendar.isJulian(julianDayNumber:2_299_161))
		#expect(JulianGregorianCalendar.isJulian(julianDayNumber:try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 4)))
		#expect(!JulianGregorianCalendar.isJulian(julianDayNumber:try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 15)))
		#expect(JulianGregorianCalendar.isJulian(julianDayNumber:.min))
		#expect(!JulianGregorianCalendar.isJulian(julianDayNumber:.max))

		#expect(JulianGregorianCalendar.isProlepticJulian(julianDayNumber: 1_704_986))
		#expect(!JulianGregorianCalendar.isProlepticJulian(julianDayNumber: 1_704_987))
		#expect(!JulianGregorianCalendar.isProlepticJulian(julianDayNumber: try JulianGregorianCalendar.julianDayNumber(year: -44, month: 1, day: 1)))
		#expect(JulianGregorianCalendar.isProlepticJulian(julianDayNumber: .min))
		#expect(!JulianGregorianCalendar.isProlepticJulian(julianDayNumber: .max))
	}

	@Test func agreesWithJulianBeforeAndGregorianAfterChangeover() throws {
		var failures: [JulianDayNumber] = []
		for J in stride(from: -1_000_000, through: 4_000_000, by: 11) {
			let date = JulianGregorianCalendar.date(julianDayNumber: J)
			let expected = J < GregorianCalendar.papalReform ? JulianCalendar.date(julianDayNumber: J) : GregorianCalendar.date(julianDayNumber: J)
			if try date != expected || JulianGregorianCalendar.julianDayNumber(for: date) != J || !JulianGregorianCalendar.isValid(date) {
				failures.append(J)
			}
		}
		#expect(failures.isEmpty)

		for Y in -1000 ... 3000 {
			let expected = Y < 1582 ? JulianCalendar.isLeapYear(Y) : GregorianCalendar.isLeapYear(Y)
			#expect(JulianGregorianCalendar.isLeapYear(Y) == expected, "Y = \(Y)")
		}
	}

	@Test func dayOfWeekIsContinuousAcrossChangeover() throws {
		let october4 = try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 4)
		let october15 = try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 10, day: 15)
		#expect(october15 == october4 + 1)
		// Thursday, October 4, 1582 was followed by Friday, October 15, 1582
		#expect(JulianGregorianCalendar.dayOfWeek(julianDayNumber: october4) == 5)
		#expect(JulianGregorianCalendar.dayOfWeek(julianDayNumber: october15) == 6)
		for J in october4 - 30 ... october15 + 30 {
			#expect(JulianGregorianCalendar.dayOfWeek(julianDayNumber: J) == GregorianCalendar.dayOfWeek(julianDayNumber: J))
			#expect(JulianGregorianCalendar.dayOfWeek(julianDayNumber: J) == JulianCalendar.dayOfWeek(julianDayNumber: J))
		}
	}

	@Test func changeoverYearDayOfYear() throws {
		let jan1 = try JulianGregorianCalendar.julianDayNumber(year: 1582, month: 1, day: 1)
		#expect(jan1 == JulianGregorianCalendar.firstDayOfChangeoverYear)
		for N in 1 ... 355 {
			let J = jan1 + N - 1
			let date = JulianGregorianCalendar.date(julianDayNumber: J)
			#expect(date.year == 1582)
			#expect(JulianGregorianCalendar.dayOfYear(julianDayNumber: J) == N)
			#expect(try JulianGregorianCalendar.dayOfYear(year: date.year, month: date.month, day: date.day) == N)
			#expect(try JulianGregorianCalendar.date(year: 1582, dayOfYear: N) == date)
		}
		#expect(JulianGregorianCalendar.date(julianDayNumber: jan1 + 355) == (1583, 1, 1))
		#expect(JulianGregorianCalendar.dayOfYear(julianDayNumber: jan1 + 355) == 1)
		#expect(JulianGregorianCalendar.dayOfYear(julianDayNumber: jan1 - 1) == 365)

		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.date(year: 1582, dayOfYear: 356) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.date(year: 1581, dayOfYear: 366) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.date(year: 1700, dayOfYear: 366) }
		#expect(try JulianGregorianCalendar.date(year: 1600, dayOfYear: 366) == (1600, 12, 31))
		#expect(try JulianGregorianCalendar.date(year: 1500, dayOfYear: 366) == (1500, 12, 31))
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dayOfYear(year: 1582, month: 13, day: 1) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dayOfYear(year: 1582, month: 10, day: 5) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.dayOfYear(year: 1582, month: 10, day: 14) }
	}

	@Test func monthLengthErrors() {
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.numberOfDays(inMonth: 0, year: 1582) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.numberOfDays(inMonth: 13, year: 1582) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.numberOfDays(inMonth: 0, year: 1000) }
		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.numberOfDays(inMonth: 13, year: 2000) }
	}

	@Test func yearLengths() {
		#expect(JulianGregorianCalendar.numberOfDays(inYear:1500) == 366)
		#expect(JulianGregorianCalendar.numberOfDays(inYear:1581) == 365)
		#expect(JulianGregorianCalendar.numberOfDays(inYear:1582) == 355)
		#expect(JulianGregorianCalendar.numberOfDays(inYear:1583) == 365)
		#expect(JulianGregorianCalendar.numberOfDays(inYear:1600) == 366)
		#expect(JulianGregorianCalendar.numberOfDays(inYear:1700) == 365)
		#expect(JulianGregorianCalendar.numberOfDays(inYear:-100) == 366)
	}

	@Test func decimalYearFromJulianDayNumber() throws {
		#expect(JulianGregorianCalendar.decimalYear(julianDayNumber: GregorianCalendar.papalReform) == 1582 + 277.0 / 355)
		#expect(try JulianGregorianCalendar.decimalYear(year: 1582, month: 10, day: 15) == 1582 + 277.0 / 355)
		#expect(try JulianGregorianCalendar.julianDayNumber(decimalYear: 1582 + 277.0 / 355) == GregorianCalendar.papalReform)
		#expect(try JulianGregorianCalendar.date(decimalYear: 1582.5) == (1582, 6, 27))

		var previous = -Double.infinity
		var failures: [JulianDayNumber] = []
		for J in stride(from: 2_290_000, through: 2_310_000, by: 1) {
			let decimalYear = JulianGregorianCalendar.decimalYear(julianDayNumber: J)
			if try decimalYear <= previous || JulianGregorianCalendar.julianDayNumber(decimalYear: decimalYear) != J {
				failures.append(J)
			}
			previous = decimalYear
		}
		#expect(failures.isEmpty)

		#expect(throws: CalendarError.invalidDate) { try JulianGregorianCalendar.decimalYear(year: 1582, month: 10, day: 10) }
		#expect(throws: CalendarError.nonFiniteValue) { try JulianGregorianCalendar.date(decimalYear: .nan) }
		#expect(throws: CalendarError.invalidDecimalYear) { try JulianGregorianCalendar.date(decimalYear: 1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianGregorianCalendar.julianDayNumber(decimalYear: 1e18) }
	}

	@Test func easterAroundChangeover() {
		// The Julian computus is used through 1582 and the Gregorian computus afterwards
		#expect(JulianGregorianCalendar.easter(year: 1582) == JulianCalendar.easter(year: 1582))
		#expect(JulianGregorianCalendar.easter(year: 1583) == GregorianCalendar.easter(year: 1583))
		for Y in -1000 ... 1582 {
			#expect(JulianGregorianCalendar.easter(year: Y) == JulianCalendar.easter(year: Y))
		}
		for Y in 1583 ... 3000 {
			#expect(JulianGregorianCalendar.easter(year: Y) == GregorianCalendar.easter(year: Y))
		}
	}

	@Test func easterIsASunday() throws {
		var failures: [Int] = []
		for Y in -1000 ... 3000 {
			let (M, D) = JulianGregorianCalendar.easter(year: Y)
			let J = try JulianGregorianCalendar.julianDayNumber(year: Y, month: M, day: D)
			if JulianGregorianCalendar.dayOfWeek(julianDayNumber: J) != 1 {
				failures.append(Y)
			}
		}
		#expect(failures.isEmpty)
	}

	@Test func agreesWithMeeus() throws {
		// Meeus applies the Gregorian correction to dates on or after October 15, 1582
		var failures: [YearMonthDay] = []
		for Y in stride(from: -4000, through: 4000, by: 3) {
			for M in 1 ... 12 {
				for D in [1, 15, 28] {
					let expected = meeusJulianDayNumber(year: Y, month: M, day: D, gregorian: (Y, M, D) >= (1582, 10, 15))
					if try JulianGregorianCalendar.julianDayNumber(year: Y, month: M, day: D) != expected || JulianGregorianCalendar.date(julianDayNumber: expected) != (Y, M, D) {
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

/// The Julian day number of a date using the algorithm in chapter 7 of Meeus,
/// *Astronomical Algorithms*, 2nd ed. (1998), in integer arithmetic. Valid for years after -4716.
private func meeusJulianDayNumber(year: Int, month: Int, day: Int, gregorian: Bool) -> JulianDayNumber {
	let (Y, M) = month > 2 ? (year, month) : (year - 1, month + 12)
	let A = floorDivide(Y, 100)
	let B = gregorian ? 2 - A + floorDivide(A, 4) : 0
	return floorDivide(1_461 * (Y + 4_716), 4) + (306_001 * (M + 1)) / 10_000 + day + B - 1_524
}
