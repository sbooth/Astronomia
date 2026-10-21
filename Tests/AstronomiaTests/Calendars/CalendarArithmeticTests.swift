//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct JulianAndGregorianArithmeticTests {
	private typealias Arithmetic = JulianAndGregorianArithmetic

	@Test func numberOfDays() {
		#expect(Arithmetic.numberOfDays(isLeap: false) == 365)
		#expect(Arithmetic.numberOfDays(isLeap: true) == 366)
	}

	@Test func numberOfDaysInMonth() throws {
		let common = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		let leap = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		for M in 1 ... 12 {
			#expect(try Arithmetic.numberOfDays(inMonth: M, isLeap: false) == common[M - 1])
			#expect(try Arithmetic.numberOfDays(inMonth: M, isLeap: true) == leap[M - 1])
		}
		#expect(common.reduce(0, +) == 365)
		#expect(leap.reduce(0, +) == 366)
		for M in [Int.min, -1, 0, 13, Int.max] {
			#expect(throws: CalendarError.invalidDate) { try Arithmetic.numberOfDays(inMonth: M, isLeap: false) }
		}
	}

	@Test func isValid() {
		#expect(Arithmetic.isValid(month: 2, day: 29, isLeap: true))
		#expect(!Arithmetic.isValid(month: 2, day: 29, isLeap: false))
		#expect(Arithmetic.isValid(month: 12, day: 31, isLeap: false))
		#expect(!Arithmetic.isValid(month: 11, day: 31, isLeap: false))
		#expect(!Arithmetic.isValid(month: 1, day: 0, isLeap: false))
		#expect(!Arithmetic.isValid(month: 0, day: 1, isLeap: false))
		#expect(!Arithmetic.isValid(month: 13, day: 1, isLeap: true))
		#expect(!Arithmetic.isValid(month: 1, day: .min, isLeap: true))
		#expect(!Arithmetic.isValid(month: 1, day: .max, isLeap: true))
	}

	@Test(arguments: [false, true])
	func dayOfYearAndMonthAndDayAreInverses(isLeap: Bool) throws {
		var N = 0
		for M in 1 ... 12 {
			let daysInMonth = try Arithmetic.numberOfDays(inMonth: M, isLeap: isLeap)
			for D in 1 ... daysInMonth {
				N += 1
				#expect(Arithmetic.dayOfYear(month: M, day: D, isLeap: isLeap) == N)
				let (month, day) = Arithmetic.monthAndDay(dayOfYear: N, isLeap: isLeap)
				#expect(month == M && day == D, "N = \(N)")
			}
		}
		#expect(N == Arithmetic.numberOfDays(isLeap: isLeap))
	}

	@Test func dayOfWeek() {
		// JDN 0 was a Monday
		#expect(Arithmetic.dayOfWeek(julianDayNumber: 0) == 2)
		for J in -50 ... 50 {
			let dow = Arithmetic.dayOfWeek(julianDayNumber: J)
			#expect((1 ... 7).contains(dow))
			#expect(Arithmetic.dayOfWeek(julianDayNumber: J + 1) == dow % 7 + 1)
			#expect(Arithmetic.dayOfWeek(julianDayNumber: J + 7) == dow)
		}
		#expect((1 ... 7).contains(Arithmetic.dayOfWeek(julianDayNumber: .min)))
		#expect((1 ... 7).contains(Arithmetic.dayOfWeek(julianDayNumber: .max)))
	}

	@Test func marchBasedYearAndMonth() throws {
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 3, 1)) == (2000, 0))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 12, 1)) == (2000, 9))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 1, 1)) == (1999, 10))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 2, 1)) == (1999, 11))
		// Out-of-range months roll over into adjacent years
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 0, 1)) == (1999, 9))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 13, 1)) == (2000, 10))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 14, 1)) == (2000, 11))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, 15, 1)) == (2001, 0))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, -9, 1)) == (1999, 0))
		#expect(try Arithmetic.marchBasedYearAndMonth((2000, -10, 1)) == (1998, 11))

		#expect(try Arithmetic.marchBasedYearAndMonth((.min, 3, 1)) == (Int.min, 0))
		#expect(try Arithmetic.marchBasedYearAndMonth((.max, 14, 1)) == (Int.max, 11))
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try Arithmetic.marchBasedYearAndMonth((.min, 1, 1)) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try Arithmetic.marchBasedYearAndMonth((.min, 0, 1)) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try Arithmetic.marchBasedYearAndMonth((.max, 15, 1)) }
	}
}

@Suite struct DecimalYearArithmeticTests {
	@Test func startOfYearIsExact() {
		for Y in [-1_000_000, -4713, -1, 0, 1, 1582, 2000, 1_000_000] {
			for d in [355, 365, 366] {
				#expect(DecimalYearArithmetic.decimalYear(year: Y, dayOfYear: 1, daysInYear: d) == Double(Y))
			}
		}
	}

	@Test func knownValues() {
		#expect(DecimalYearArithmetic.decimalYear(year: 1985, dayOfYear: 183, daysInYear: 365) == 1985 + 182.0 / 365)
		#expect(DecimalYearArithmetic.decimalYear(year: 1985, dayOfYear: 183, fractionSinceMidnight: 0.5, daysInYear: 365) == 1985.5)
		#expect(DecimalYearArithmetic.decimalYear(year: 2000, dayOfYear: 184, daysInYear: 366) == 2000.5)
		#expect(DecimalYearArithmetic.decimalYear(year: 1582, dayOfYear: 278, daysInYear: 355) == 1582 + 277.0 / 355)
		#expect(DecimalYearArithmetic.decimalYear(year: -1, dayOfYear: 183, fractionSinceMidnight: 0.5, daysInYear: 365) == -0.5)
	}

	@Test(arguments: [355, 365, 366])
	func startOfDayIsMonotonicAndInvertible(daysInYear d: Int) {
		for Y in [-100_000, -4713, -1, 0, 1, 1582, 2024, 100_000] {
			var previous = -Double.infinity
			for N in 1 ... d {
				let decimalYear = DecimalYearArithmetic.decimalYear(year: Y, dayOfYear: N, daysInYear: d)
				#expect(decimalYear > previous, "Y = \(Y), N = \(N)")
				#expect(decimalYear >= Double(Y) && decimalYear < Double(Y + 1), "Y = \(Y), N = \(N)")
				previous = decimalYear

				let yearFraction = decimalYear - Double(Y)
				#expect(DecimalYearArithmetic.dayOfYear(decimalYear: decimalYear, year: Y, yearFraction: yearFraction, daysInYear: d) == N, "Y = \(Y), N = \(N)")

				// Just before the start of the next day is still day N
				let noon = DecimalYearArithmetic.decimalYear(year: Y, dayOfYear: N, fractionSinceMidnight: 0.5, daysInYear: d)
				#expect(DecimalYearArithmetic.dayOfYear(decimalYear: noon, year: Y, yearFraction: noon - Double(Y), daysInYear: d) == N, "Y = \(Y), N = \(N)")
			}
		}
	}

	@Test func yearAndDayOfYear() throws {
		let julianDays: (Int) -> Int = JulianCalendar.numberOfDays(inYear:)
		let gregorianDays: (Int) -> Int = GregorianCalendar.numberOfDays(inYear:)
		let hybridDays: (Int) -> Int = JulianGregorianCalendar.numberOfDays(inYear:)

		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: 2000, daysInYear: gregorianDays) == (2000, 1))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: 2000.5, daysInYear: gregorianDays) == (2000, 184))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: 2000.5, daysInYear: julianDays) == (2000, 184))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: 1900.5, daysInYear: gregorianDays) == (1900, 183))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: 1900.5, daysInYear: julianDays) == (1900, 184))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: 1582.5, daysInYear: hybridDays) == (1582, 178))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: Double(2001).nextDown, daysInYear: gregorianDays) == (2000, 366))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: -0.5, daysInYear: julianDays) == (-1, 183))

		// Tiny negative decimal years whose fraction rounds to 1 are the last day of year -1
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: -1e-20, daysInYear: julianDays) == (-1, 365))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: -0x1p-54, daysInYear: gregorianDays) == (-1, 365))
		#expect(try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: -0.0, daysInYear: gregorianDays) == (0, 1))

		#expect(throws: CalendarError.nonFiniteValue) { try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: .nan, daysInYear: julianDays) }
		#expect(throws: CalendarError.nonFiniteValue) { try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: .infinity, daysInYear: julianDays) }
		#expect(throws: CalendarError.invalidDecimalYear) { try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: 0x1p63, daysInYear: julianDays) }
		#expect(throws: CalendarError.invalidDecimalYear) { try DecimalYearArithmetic.yearAndDayOfYear(decimalYear: -1e300, daysInYear: julianDays) }
	}
}
