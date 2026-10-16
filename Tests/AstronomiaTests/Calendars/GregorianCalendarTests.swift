//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct GregorianCalendarTests {
	@Test func epoch() throws {
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 1, month: 1, day: 1) == GregorianCalendar.epoch)
		#expect(GregorianCalendar.dateFromJulianDayNumber(GregorianCalendar.epoch) == (1, 1, 1))
	}

	@Test func constants() throws {
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 0, month: 3, day: 1) == 1_721_120)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 0, month: 2, day: 29) == 1_721_119)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 1, month: 1, day: 1) == 1_721_426)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -4713, month: 11, day: 24) == 0)
	}

	@Test func dateValidation() {
		#expect(GregorianCalendar.isValid(year: 1600, month: 2, day: 29))
		#expect(!GregorianCalendar.isValid(year: 1700, month: 2, day: 29))
	}

	@Test func leapYear() throws {
		#expect(GregorianCalendar.isLeapYear(4))
		#expect(!GregorianCalendar.isLeapYear(100))
		#expect(GregorianCalendar.isLeapYear(1600))
		#expect(!GregorianCalendar.isLeapYear(1700))
		#expect(!GregorianCalendar.isLeapYear(1800))
		#expect(!GregorianCalendar.isLeapYear(1900))
		#expect(GregorianCalendar.isLeapYear(2000))
		#expect(!GregorianCalendar.isLeapYear(2100))
		#expect(GregorianCalendar.isLeapYear(2400))
		#expect(!GregorianCalendar.isLeapYear(-3))
		#expect(GregorianCalendar.isLeapYear(-4))
		#expect(GregorianCalendar.isLeapYear(-8))
		#expect(!GregorianCalendar.isLeapYear(-100))

		for y in 1583...2500 {
			let isLeap = GregorianCalendar.isLeapYear(y)
			let j = try GregorianCalendar.julianDayNumberFrom(year: y, month: 2, day: isLeap ? 29 : 28)
			let d = GregorianCalendar.dateFromJulianDayNumber(j)
			#expect(d.month == 2)
			#expect(d.day == (isLeap ? 29 : 28))
		}
	}

	@Test func monthCount() {
		#expect(GregorianCalendar.numberOfMonthsInYear == 12)
	}

	@Test func monthLength() throws {
		#expect(try GregorianCalendar.numberOfDaysIn(month: 2, year: 1600) == 29)
		#expect(try GregorianCalendar.numberOfDaysIn(month: 2, year: 1700) == 28)
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.numberOfDaysIn(month: 0, year: 1000) }
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.numberOfDaysIn(month: 13, year: 1000) }
	}

	@Test func yearLength() throws {
		#expect(GregorianCalendar.numberOfDaysInYear(4) == 366)
		#expect(GregorianCalendar.numberOfDaysInYear(1581) == 365)
		#expect(GregorianCalendar.numberOfDaysInYear(1582) == 365)
		#expect(GregorianCalendar.numberOfDaysInYear(1583) == 365)
		#expect(GregorianCalendar.numberOfDaysInYear(1600) == 366)

		var sum = 0
		for m in 1 ... 12 {
			sum += try GregorianCalendar.numberOfDaysIn(month: m, year: 1961)
		}

		let jan1 = try GregorianCalendar.julianDayNumberFrom(year: 1961, month: 1, day: 1)
		let dec31 = try GregorianCalendar.julianDayNumberFrom(year: 1961, month: 12, day: 31)

		#expect(GregorianCalendar.numberOfDaysInYear(1961) == sum)
		#expect(sum == (dec31 - jan1 + 1))
	}

	@Test func dayOfYear() throws {
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.dayOfYearFrom(year: 1500, month: 2, day: 29) }
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.dayOfYearFrom(year: 1700, month: 2, day: 29) }
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.dateFrom(year: 1500, dayOfYear: 0) }
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.dateFrom(year: 1700, dayOfYear: 366) }
	}

	@Test func decimalYear() throws {
		for Y in [-401, -400, -100, 1900, 2000, 2023, 2024] {
			for N in 1...GregorianCalendar.numberOfDaysInYear(Y) {
				let date = try GregorianCalendar.dateFrom(year: Y, dayOfYear: N)
				let y = try GregorianCalendar.decimalYearFrom(year: date.year, month: date.month, day: date.day)
				#expect(try GregorianCalendar.dateFromDecimalYear(y) == date)
			}
		}
		#expect(try GregorianCalendar.dateFromDecimalYear(-0x1p-53) == (-1, 12, 31))  // fraction rounds but doesn't carry
		#expect(try GregorianCalendar.dateFromDecimalYear(-0x1p-54) == (-1, 12, 31))  // tie rounds to 1 and carries
		#expect(try GregorianCalendar.dateFromDecimalYear(-1e-20) == (-1, 12, 31))	}

	@Test func easter() {
		// Dates from Meeus (1998)
		#expect(GregorianCalendar.easter(year: 1991) == (3, 31))
		#expect(GregorianCalendar.easter(year: 1992) == (4, 19))
		#expect(GregorianCalendar.easter(year: 1993) == (4, 11))
		#expect(GregorianCalendar.easter(year: 1954) == (4, 18))
		#expect(GregorianCalendar.easter(year: 2000) == (4, 23))
		#expect(GregorianCalendar.easter(year: 1818) == (3, 22))
	}

	@Test func julianDayNumber() throws {
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -999999, month: 1, day: 1) == -363521074)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -99999, month: 1, day: 1) == -34802824)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -9999, month: 1, day: 1) == -1930999)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 9999, month: 12, day: 31) == 5373484)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 99999, month: 12, day: 31) == 38245309)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 999999, month: 12, day: 31) == 366963559)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -4712, month: 1, day: 1) == 38)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -4713, month: 11, day: 23) == -1)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -4713, month: 11, day: 24) == 0)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -4713, month: 11, day: 25) == 1)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 4) == 2299150)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 15) == 2299161)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: 2000, month: 1, day: 1) == 2451545)
		#expect(try GregorianCalendar.julianDayNumberFrom(year: -5000, month: 1, day: 1) == -105152)

		#expect(GregorianCalendar.dateFromJulianDayNumber(-363521074) == (-999999, 1, 1))
		#expect(GregorianCalendar.dateFromJulianDayNumber(-34802824) == (-99999, 1, 1))
		#expect(GregorianCalendar.dateFromJulianDayNumber(-1930999) == (-9999, 1, 1))
		#expect(GregorianCalendar.dateFromJulianDayNumber(5373484) == (9999, 12, 31))
		#expect(GregorianCalendar.dateFromJulianDayNumber(38245309) == (99999, 12, 31))
		#expect(GregorianCalendar.dateFromJulianDayNumber(366963559) == (999999, 12, 31))
		#expect(GregorianCalendar.dateFromJulianDayNumber(38) == (-4712, 1, 1))
		#expect(GregorianCalendar.dateFromJulianDayNumber(-1) == (-4713, 11, 23))
		#expect(GregorianCalendar.dateFromJulianDayNumber(0) == (-4713, 11, 24))
		#expect(GregorianCalendar.dateFromJulianDayNumber(1) == (-4713, 11, 25))
		#expect(GregorianCalendar.dateFromJulianDayNumber(2299150) == (1582, 10, 4))
		#expect(GregorianCalendar.dateFromJulianDayNumber(2299161) == (1582, 10, 15))
		#expect(GregorianCalendar.dateFromJulianDayNumber(2451545) == (2000, 1, 1))
		#expect(GregorianCalendar.dateFromJulianDayNumber(-105152) == (-5000, 1, 1))
	}

	@Test func range() throws {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try GregorianCalendar.julianDayNumberFrom(year: .min, month: 1, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try GregorianCalendar.julianDayNumberFrom(year: .max, month: 1, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try GregorianCalendar.julianDayNumberFrom(year: 1, month: .min, day: 1)
		}
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) {
			_ = try GregorianCalendar.julianDayNumberFrom(year: 1, month: .max, day: 1)
		}
	}

	@Test func limits() throws {
		let minDate = GregorianCalendar.dateFromJulianDayNumber(.min)
		let minJ = try GregorianCalendar.julianDayNumberFromDate(minDate)
		#expect(minJ == .min)

		let maxDate = GregorianCalendar.dateFromJulianDayNumber(.max)
		let maxJ = try GregorianCalendar.julianDayNumberFromDate(maxDate)
		#expect(maxJ == .max)

		_ = GregorianCalendar.isLeapYear(.min)
		_ = GregorianCalendar.isLeapYear(.max)

		_ = GregorianCalendar.dayOfWeek(.min)
		_ = GregorianCalendar.dayOfWeek(.max)
	}

	@Test func normalize() throws {
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: 13, day: 1) == (2001, 1, 1))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: 25, day: 1) == (2002, 1, 1))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: 0, day: 1) == (1999, 12, 1))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: -11, day: 1) == (1999, 1, 1))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: -12, day: 1) == (1998, 12, 1))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 1900, month: 2, day: 29) == (1900, 3, 1))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: 2, day: 30) == (2000, 3, 1))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: 3, day: 0) == (2000, 2, 29))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 1900, month: 3, day: 0) == (1900, 2, 28))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: 1, day: 366) == (2000, 12, 31))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2001, month: 1, day: -364) == (2000, 1, 2))
		#expect(try GregorianCalendar.normalizedDateFrom(year: 2000, month: 1, day: 146_098) == (2400, 1, 1))
		#expect(try GregorianCalendar.normalizedDate((2000, 14, 30)) == (2001, 3, 2))

		// Valid dates are unchanged
		for J in stride(from: 2_400_000, through: 2_500_000, by: 13) {
			let date = GregorianCalendar.dateFromJulianDayNumber(J)
			#expect(try GregorianCalendar.normalizedDate(date) == date)
		}

		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try GregorianCalendar.normalizedDateFrom(year: .max, month: 12, day: 31) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try GregorianCalendar.normalizedDateFrom(year: 2000, month: 1, day: .max) }
	}

	@Test func invalidDates() {
		#expect(GregorianCalendar.isValid(year: 2000, month: 2, day: 29))
		#expect(GregorianCalendar.isValid(year: 1582, month: 10, day: 10))
		#expect(GregorianCalendar.isValid(year: -4, month: 2, day: 29))
		#expect(!GregorianCalendar.isValid(year: -100, month: 2, day: 29))
		#expect(!GregorianCalendar.isValid(year: 2001, month: 2, day: 29))
		#expect(!GregorianCalendar.isValid(year: 2000, month: 4, day: 31))
		#expect(!GregorianCalendar.isValid(year: 2000, month: 0, day: 1))
		#expect(!GregorianCalendar.isValid(year: 2000, month: 13, day: 1))
		#expect(!GregorianCalendar.isValid(year: 2000, month: 1, day: 0))
		#expect(!GregorianCalendar.isValid(year: 2000, month: 1, day: 32))
		#expect(!GregorianCalendar.isValidDate((2000, 12, -1)))
	}

	@Test func papalReform() {
		#expect(GregorianCalendar.beforePapalReform(2_299_160))
		#expect(!GregorianCalendar.beforePapalReform(2_299_161))
		#expect(GregorianCalendar.beforePapalReform(.min))
		#expect(!GregorianCalendar.beforePapalReform(.max))
	}

	@Test func dayOfWeek() throws {
		// Saturday, January 1, 2000
		#expect(GregorianCalendar.dayOfWeek(try GregorianCalendar.julianDayNumberFrom(year: 2000, month: 1, day: 1)) == 7)
		// Friday, October 15, 1582
		#expect(GregorianCalendar.dayOfWeek(try GregorianCalendar.julianDayNumberFrom(year: 1582, month: 10, day: 15)) == 6)
		// Sunday, July 20, 1969
		#expect(GregorianCalendar.dayOfWeek(try GregorianCalendar.julianDayNumberFrom(year: 1969, month: 7, day: 20)) == 1)
		// Thursday, July 4, 1776
		#expect(GregorianCalendar.dayOfWeek(try GregorianCalendar.julianDayNumberFrom(year: 1776, month: 7, day: 4)) == 5)
		// Wednesday, October 14, 2026
		#expect(GregorianCalendar.dayOfWeek(try GregorianCalendar.julianDayNumberFrom(year: 2026, month: 10, day: 14)) == 4)

		// The day of the week repeats every 400 years
		for J in stride(from: 2_400_000, through: 2_401_000, by: 1) {
			#expect(GregorianCalendar.dayOfWeek(J) == GregorianCalendar.dayOfWeek(J + 146_097))
		}
	}

	@Test func dayOfYearTables() throws {
		for (Y, daysInYear) in [(1900, 365), (2000, 366), (2001, 365), (-4, 366), (-100, 365)] {
			let jan1 = try GregorianCalendar.julianDayNumberFrom(year: Y, month: 1, day: 1)
			for N in 1 ... daysInYear {
				let date = try GregorianCalendar.dateFrom(year: Y, dayOfYear: N)
				#expect(date.year == Y)
				#expect(try GregorianCalendar.dayOfYearFrom(year: date.year, month: date.month, day: date.day) == N)
				#expect(try GregorianCalendar.julianDayNumberFromDate(date) == jan1 + N - 1)
				#expect(GregorianCalendar.dayOfYearFromJulianDayNumber(jan1 + N - 1) == N)
			}
			#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.dateFrom(year: Y, dayOfYear: daysInYear + 1) }
		}
		#expect(try GregorianCalendar.dayOfYearFrom(year: 1900, month: 3, day: 1) == 60)
		#expect(try GregorianCalendar.dayOfYearFrom(year: 2000, month: 3, day: 1) == 61)
		#expect(try GregorianCalendar.dayOfYearFrom(year: 2000, month: 12, day: 31) == 366)
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.dateFrom(year: 2000, dayOfYear: -1) }
		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.dayOfYearFrom(year: 2000, month: 13, day: 1) }
	}

	@Test func decimalYearFromJulianDayNumber() throws {
		#expect(GregorianCalendar.decimalYearFromJulianDayNumber(2_451_545) == 2000)
		#expect(try GregorianCalendar.decimalYearFrom(year: 1985, month: 1, day: 1) == 1985)
		#expect(try GregorianCalendar.decimalYearFrom(year: 1985, month: 7, day: 2) == 1985 + 182.0 / 365)
		#expect(try GregorianCalendar.decimalYearFrom(year: 2000, month: 7, day: 2) == 2000.5)
		#expect(try GregorianCalendar.julianDayNumberFromDecimalYear(2000.5) == 2_451_728)
		#expect(try GregorianCalendar.dateFromDecimalYear(1985.5) == (1985, 7, 2))

		var previous = -Double.infinity
		var failures: [JulianDayNumber] = []
		for J in stride(from: -2_000_000, through: 4_000_000, by: 97) {
			let decimalYear = GregorianCalendar.decimalYearFromJulianDayNumber(J)
			if try decimalYear <= previous || GregorianCalendar.julianDayNumberFromDecimalYear(decimalYear) != J {
				failures.append(J)
			}
			previous = decimalYear
		}
		#expect(failures.isEmpty)

		#expect(throws: CalendarError.invalidDate) { try GregorianCalendar.decimalYearFrom(year: 1900, month: 2, day: 29) }
		#expect(throws: CalendarError.nonFiniteValue) { try GregorianCalendar.dateFromDecimalYear(.nan) }
		#expect(throws: CalendarError.nonFiniteValue) { try GregorianCalendar.dateFromDecimalYear(.infinity) }
		#expect(throws: CalendarError.invalidDecimalYear) { try GregorianCalendar.dateFromDecimalYear(1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try GregorianCalendar.julianDayNumberFromDecimalYear(1e18) }
	}

	@Test func easterDates() {
		#expect(GregorianCalendar.easter(year: 1961) == (4, 2))
		#expect(GregorianCalendar.easter(year: 2008) == (3, 23))
		#expect(GregorianCalendar.easter(year: 2019) == (4, 21))
		#expect(GregorianCalendar.easter(year: 2024) == (3, 31))
		#expect(GregorianCalendar.easter(year: 2025) == (4, 20))
		#expect(GregorianCalendar.easter(year: 2026) == (4, 5))
		// The latest and earliest possible dates
		#expect(GregorianCalendar.easter(year: 2038) == (4, 25))
		#expect(GregorianCalendar.easter(year: 2285) == (3, 22))
	}

	@Test func easterIsASundayBetweenMarch22AndApril25() throws {
		var failures: [Int] = []
		for Y in -3000 ... 5000 {
			let (M, D) = GregorianCalendar.easter(year: Y)
			let J = try GregorianCalendar.julianDayNumberFrom(year: Y, month: M, day: D)
			if GregorianCalendar.dayOfWeek(J) != 1 || (M, D) < (3, 22) || (M, D) > (4, 25) {
				failures.append(Y)
			}
		}
		#expect(failures.isEmpty)
	}

	@Test func easterPeriodicity() {
		for Y in [-1, 0, 1, 1583, 2026] {
			#expect(GregorianCalendar.easter(year: Y) == GregorianCalendar.easter(year: Y + 5_700_000))
			#expect(GregorianCalendar.easter(year: Y) == GregorianCalendar.easter(year: Y - 5_700_000))
		}
		#expect(GregorianCalendar.easter(year: .max) == GregorianCalendar.easter(year: Int.max % 5_700_000))
		_ = GregorianCalendar.easter(year: .min)
	}

	@Test func julianDayNumberRoundTrip() throws {
		var failures: [JulianDayNumber] = []
		for J in stride(from: -2_000_000, through: 6_000_000, by: 29) {
			let date = GregorianCalendar.dateFromJulianDayNumber(J)
			if try !GregorianCalendar.isValidDate(date) || GregorianCalendar.julianDayNumberFromDate(date) != J {
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
					if try GregorianCalendar.julianDayNumberFrom(year: Y, month: M, day: D) != expected || GregorianCalendar.dateFromJulianDayNumber(expected) != (Y, M, D) {
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

/// The Julian day number of a proleptic Gregorian date using the algorithm in chapter 7 of
/// Meeus, *Astronomical Algorithms*, 2nd ed. (1998), in integer arithmetic. Valid for years
/// after -4716.
private func meeusJulianDayNumber(year: Int, month: Int, day: Int) -> JulianDayNumber {
	let (Y, M) = month > 2 ? (year, month) : (year - 1, month + 12)
	let A = floorDivide(Y, 100)
	let B = 2 - A + floorDivide(A, 4)
	return floorDivide(1_461 * (Y + 4_716), 4) + (306_001 * (M + 1)) / 10_000 + day + B - 1_524
}
