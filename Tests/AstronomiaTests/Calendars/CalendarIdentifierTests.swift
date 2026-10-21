//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Julian day numbers spanning the Julian to Gregorian changeover, plus a few distant days.
private let sampleJulianDayNumbers: [JulianDayNumber] = Array(2_298_500 ... 2_300_000) + [-1_931_076, -105_192, -1, 0, 1, 1_721_424, 2_451_545, 5_373_484]

private func staticDate(_ calendar: CalendarIdentifier, _ J: JulianDayNumber) -> YearMonthDay {
	switch calendar {
	case .julian: JulianCalendar.date(julianDayNumber: J)
	case .gregorian: GregorianCalendar.date(julianDayNumber: J)
	case .julianGregorian: JulianGregorianCalendar.date(julianDayNumber: J)
	}
}

private func staticDayOfYear(_ calendar: CalendarIdentifier, _ J: JulianDayNumber) -> Int {
	switch calendar {
	case .julian: JulianCalendar.dayOfYear(julianDayNumber: J)
	case .gregorian: GregorianCalendar.dayOfYear(julianDayNumber: J)
	case .julianGregorian: JulianGregorianCalendar.dayOfYear(julianDayNumber: J)
	}
}

private func staticDecimalYear(_ calendar: CalendarIdentifier, _ J: JulianDayNumber) -> Double {
	switch calendar {
	case .julian: JulianCalendar.decimalYear(julianDayNumber: J)
	case .gregorian: GregorianCalendar.decimalYear(julianDayNumber: J)
	case .julianGregorian: JulianGregorianCalendar.decimalYear(julianDayNumber: J)
	}
}

private func staticIsLeapYear(_ calendar: CalendarIdentifier, _ Y: Int) -> Bool {
	switch calendar {
	case .julian: JulianCalendar.isLeapYear(Y)
	case .gregorian: GregorianCalendar.isLeapYear(Y)
	case .julianGregorian: JulianGregorianCalendar.isLeapYear(Y)
	}
}

private func staticNumberOfDaysInYear(_ calendar: CalendarIdentifier, _ Y: Int) -> Int {
	switch calendar {
	case .julian: JulianCalendar.numberOfDays(inYear:Y)
	case .gregorian: GregorianCalendar.numberOfDays(inYear:Y)
	case .julianGregorian: JulianGregorianCalendar.numberOfDays(inYear:Y)
	}
}

private func staticNumberOfDaysIn(_ calendar: CalendarIdentifier, month M: Int, year Y: Int) throws(CalendarError) -> Int {
	switch calendar {
	case .julian: return try JulianCalendar.numberOfDays(inMonth: M, year: Y)
	case .gregorian: return try GregorianCalendar.numberOfDays(inMonth: M, year: Y)
	case .julianGregorian: return try JulianGregorianCalendar.numberOfDays(inMonth: M, year: Y)
	}
}

@Suite struct CalendarIdentifierTests {
	@Test func allCases() {
		#expect(CalendarIdentifier.allCases == [.julian, .gregorian, .julianGregorian])
	}

	@Test func names() {
		#expect(CalendarIdentifier.julian.name == "Julian")
		#expect(CalendarIdentifier.gregorian.name == "Gregorian")
		#expect(CalendarIdentifier.julianGregorian.name == "Julian-Gregorian")
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func julianDayNumberConversionMatchesStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for J in sampleJulianDayNumbers {
			let date = calendar.date(julianDayNumber: J)
			#expect(date == staticDate(calendar, J), "J = \(J)")
			#expect(try calendar.julianDayNumber(for: date) == J, "J = \(J)")
			#expect(try calendar.julianDayNumber(year: date.year, month: date.month, day: date.day) == J, "J = \(J)")
			#expect(calendar.isValid(date), "J = \(J)")
			#expect(calendar.isValid(year: date.year, month: date.month, day: date.day), "J = \(J)")
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func dayOfYearMatchesStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for J in sampleJulianDayNumbers {
			let N = calendar.dayOfYear(julianDayNumber: J)
			#expect(N == staticDayOfYear(calendar, J), "J = \(J)")
			let date = calendar.date(julianDayNumber: J)
			#expect(try calendar.dayOfYear(year: date.year, month: date.month, day: date.day) == N, "J = \(J)")
			#expect(try calendar.date(year: date.year, dayOfYear: N) == date, "J = \(J)")
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func decimalYearMatchesStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for J in sampleJulianDayNumbers {
			let decimalYear = calendar.decimalYear(julianDayNumber: J)
			#expect(decimalYear == staticDecimalYear(calendar, J), "J = \(J)")
			let date = calendar.date(julianDayNumber: J)
			#expect(try calendar.decimalYear(year: date.year, month: date.month, day: date.day) == decimalYear, "J = \(J)")
			#expect(try calendar.date(decimalYear: decimalYear) == date, "J = \(J)")
			#expect(try calendar.julianDayNumber(decimalYear: decimalYear) == J, "J = \(J)")
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func yearAndMonthLengthsMatchStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for Y in [-4713, -101, -100, -5, -4, -1, 0, 1, 4, 100, 1500, 1581, 1582, 1583, 1600, 1700, 1900, 2000, 2024, 2100] {
			#expect(calendar.isLeapYear(Y) == staticIsLeapYear(calendar, Y), "Y = \(Y)")
			#expect(calendar.numberOfDays(inYear:Y) == staticNumberOfDaysInYear(calendar, Y), "Y = \(Y)")
			var sum = 0
			for M in 1 ... 12 {
				let days = try calendar.numberOfDays(inMonth: M, year: Y)
				#expect(try days == staticNumberOfDaysIn(calendar, month: M, year: Y), "Y = \(Y), M = \(M)")
				sum += days
			}
			#expect(sum == calendar.numberOfDays(inYear:Y), "Y = \(Y)")
		}
	}

	@Test(arguments: zip(CalendarIdentifier.allCases, [true, false, false]))
	func validityOfFebruary29_1900(_ calendar: CalendarIdentifier, isValid: Bool) {
		#expect(calendar.isValid(year: 1900, month: 2, day: 29) == isValid)
		#expect(calendar.isValid((1900, 2, 29)) == isValid)
	}

	@Test(arguments: zip(CalendarIdentifier.allCases, [true, true, false]))
	func validityOfOctober10_1582(_ calendar: CalendarIdentifier, isValid: Bool) {
		#expect(calendar.isValid(year: 1582, month: 10, day: 10) == isValid)
		#expect(calendar.isValid((1582, 10, 10)) == isValid)
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func invalidComponents(_ calendar: CalendarIdentifier) {
		#expect(!calendar.isValid(year: 2000, month: 0, day: 1))
		#expect(!calendar.isValid(year: 2000, month: 13, day: 1))
		#expect(!calendar.isValid(year: 2000, month: 1, day: 0))
		#expect(!calendar.isValid(year: 2000, month: 1, day: 32))
		#expect(!calendar.isValid(year: 2000, month: 4, day: 31))
		#expect(!calendar.isValid(year: 2001, month: 2, day: 29))
	}

	@Test func normalizedDate() throws {
		#expect(try CalendarIdentifier.julian.normalizedDate(year: 1900, month: 2, day: 29) == (1900, 2, 29))
		#expect(try CalendarIdentifier.gregorian.normalizedDate(year: 1900, month: 2, day: 29) == (1900, 3, 1))
		#expect(try CalendarIdentifier.julianGregorian.normalizedDate(year: 1900, month: 2, day: 29) == (1900, 3, 1))

		#expect(try CalendarIdentifier.julian.normalizedDate((1582, 10, 10)) == (1582, 10, 10))
		#expect(try CalendarIdentifier.gregorian.normalizedDate((1582, 10, 10)) == (1582, 10, 10))
		#expect(try CalendarIdentifier.julianGregorian.normalizedDate((1582, 10, 10)) == (1582, 10, 20))

		for calendar in CalendarIdentifier.allCases {
			#expect(try calendar.normalizedDate(year: 2000, month: 13, day: 1) == (2001, 1, 1))
			#expect(try calendar.normalizedDate(year: 2000, month: 1, day: 0) == (1999, 12, 31))
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func errors(_ calendar: CalendarIdentifier) {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.julianDayNumber(year: .max, month: 1, day: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.julianDayNumber(year: .min, month: 1, day: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.normalizedDate(year: .max, month: 1, day: 1) }
		#expect(throws: CalendarError.invalidDate) { try calendar.numberOfDays(inMonth: 0, year: 2000) }
		#expect(throws: CalendarError.invalidDate) { try calendar.numberOfDays(inMonth: 13, year: 2000) }
		#expect(throws: CalendarError.invalidDate) { try calendar.dayOfYear(year: 2001, month: 2, day: 29) }
		#expect(throws: CalendarError.invalidDate) { try calendar.date(year: 2001, dayOfYear: 0) }
		#expect(throws: CalendarError.invalidDate) { try calendar.date(year: 2001, dayOfYear: 366) }
		#expect(throws: CalendarError.invalidDate) { try calendar.decimalYear(year: 2001, month: 2, day: 29) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.date(decimalYear: .nan) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.date(decimalYear: .infinity) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.date(decimalYear: -.infinity) }
		#expect(throws: CalendarError.invalidDecimalYear) { try calendar.date(decimalYear: 1e300) }
		#expect(throws: CalendarError.invalidDecimalYear) { try calendar.date(decimalYear: -1e300) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.julianDayNumber(decimalYear: .nan) }
		#expect(throws: CalendarError.invalidDecimalYear) { try calendar.julianDayNumber(decimalYear: 1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.julianDayNumber(decimalYear: 1e18) }
	}
}

#if canImport(Foundation)

import Foundation

@Suite struct CalendarIdentifierCodableTests {
	@Test(arguments: CalendarIdentifier.allCases)
	func codableRoundTrip(_ calendar: CalendarIdentifier) throws {
		let data = try JSONEncoder().encode(calendar)
		#expect(try JSONDecoder().decode(CalendarIdentifier.self, from: data) == calendar)
	}
}

#endif
