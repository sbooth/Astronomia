//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import Testing
@testable import Astronomia

/// Julian day numbers spanning the Julian to Gregorian changeover, plus a few distant days.
private let sampleJulianDayNumbers: [JulianDayNumber] = Array(2_298_500 ... 2_300_000) + [-1_931_076, -105_192, -1, 0, 1, 1_721_424, 2_451_545, 5_373_484]

private func staticDate(_ calendar: CalendarIdentifier, _ J: JulianDayNumber) -> YearMonthDay {
	switch calendar {
	case .julian: JulianCalendar.dateFromJulianDayNumber(J)
	case .gregorian: GregorianCalendar.dateFromJulianDayNumber(J)
	case .julianGregorian: JulianGregorianCalendar.dateFromJulianDayNumber(J)
	}
}

private func staticDayOfYear(_ calendar: CalendarIdentifier, _ J: JulianDayNumber) -> Int {
	switch calendar {
	case .julian: JulianCalendar.dayOfYearFromJulianDayNumber(J)
	case .gregorian: GregorianCalendar.dayOfYearFromJulianDayNumber(J)
	case .julianGregorian: JulianGregorianCalendar.dayOfYearFromJulianDayNumber(J)
	}
}

private func staticDecimalYear(_ calendar: CalendarIdentifier, _ J: JulianDayNumber) -> Double {
	switch calendar {
	case .julian: JulianCalendar.decimalYearFromJulianDayNumber(J)
	case .gregorian: GregorianCalendar.decimalYearFromJulianDayNumber(J)
	case .julianGregorian: JulianGregorianCalendar.decimalYearFromJulianDayNumber(J)
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
	case .julian: JulianCalendar.numberOfDaysInYear(Y)
	case .gregorian: GregorianCalendar.numberOfDaysInYear(Y)
	case .julianGregorian: JulianGregorianCalendar.numberOfDaysInYear(Y)
	}
}

private func staticNumberOfDaysIn(_ calendar: CalendarIdentifier, month M: Int, year Y: Int) throws(CalendarError) -> Int {
	switch calendar {
	case .julian: return try JulianCalendar.numberOfDaysIn(month: M, year: Y)
	case .gregorian: return try GregorianCalendar.numberOfDaysIn(month: M, year: Y)
	case .julianGregorian: return try JulianGregorianCalendar.numberOfDaysIn(month: M, year: Y)
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
	func codableRoundTrip(_ calendar: CalendarIdentifier) throws {
		let data = try JSONEncoder().encode(calendar)
		#expect(try JSONDecoder().decode(CalendarIdentifier.self, from: data) == calendar)
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func julianDayNumberConversionMatchesStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for J in sampleJulianDayNumbers {
			let date = calendar.dateFromJulianDayNumber(J)
			#expect(date == staticDate(calendar, J), "J = \(J)")
			#expect(try calendar.julianDayNumberFromDate(date) == J, "J = \(J)")
			#expect(try calendar.julianDayNumberFrom(year: date.year, month: date.month, day: date.day) == J, "J = \(J)")
			#expect(calendar.isValidDate(date), "J = \(J)")
			#expect(calendar.isValid(year: date.year, month: date.month, day: date.day), "J = \(J)")
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func dayOfYearMatchesStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for J in sampleJulianDayNumbers {
			let N = calendar.dayOfYearFromJulianDayNumber(J)
			#expect(N == staticDayOfYear(calendar, J), "J = \(J)")
			let date = calendar.dateFromJulianDayNumber(J)
			#expect(try calendar.dayOfYearFrom(year: date.year, month: date.month, day: date.day) == N, "J = \(J)")
			#expect(try calendar.dateFrom(year: date.year, dayOfYear: N) == date, "J = \(J)")
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func decimalYearMatchesStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for J in sampleJulianDayNumbers {
			let decimalYear = calendar.decimalYearFromJulianDayNumber(J)
			#expect(decimalYear == staticDecimalYear(calendar, J), "J = \(J)")
			let date = calendar.dateFromJulianDayNumber(J)
			#expect(try calendar.decimalYearFrom(year: date.year, month: date.month, day: date.day) == decimalYear, "J = \(J)")
			#expect(try calendar.dateFromDecimalYear(decimalYear) == date, "J = \(J)")
			#expect(try calendar.julianDayNumberFromDecimalYear(decimalYear) == J, "J = \(J)")
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func yearAndMonthLengthsMatchStaticCalendar(_ calendar: CalendarIdentifier) throws {
		for Y in [-4713, -101, -100, -5, -4, -1, 0, 1, 4, 100, 1500, 1581, 1582, 1583, 1600, 1700, 1900, 2000, 2024, 2100] {
			#expect(calendar.isLeapYear(Y) == staticIsLeapYear(calendar, Y), "Y = \(Y)")
			#expect(calendar.numberOfDaysInYear(Y) == staticNumberOfDaysInYear(calendar, Y), "Y = \(Y)")
			var sum = 0
			for M in 1 ... 12 {
				let days = try calendar.numberOfDaysIn(month: M, year: Y)
				#expect(try days == staticNumberOfDaysIn(calendar, month: M, year: Y), "Y = \(Y), M = \(M)")
				sum += days
			}
			#expect(sum == calendar.numberOfDaysInYear(Y), "Y = \(Y)")
		}
	}

	@Test(arguments: zip(CalendarIdentifier.allCases, [true, false, false]))
	func validityOfFebruary29_1900(_ calendar: CalendarIdentifier, isValid: Bool) {
		#expect(calendar.isValid(year: 1900, month: 2, day: 29) == isValid)
		#expect(calendar.isValidDate((1900, 2, 29)) == isValid)
	}

	@Test(arguments: zip(CalendarIdentifier.allCases, [true, true, false]))
	func validityOfOctober10_1582(_ calendar: CalendarIdentifier, isValid: Bool) {
		#expect(calendar.isValid(year: 1582, month: 10, day: 10) == isValid)
		#expect(calendar.isValidDate((1582, 10, 10)) == isValid)
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
		#expect(try CalendarIdentifier.julian.normalizedDateFrom(year: 1900, month: 2, day: 29) == (1900, 2, 29))
		#expect(try CalendarIdentifier.gregorian.normalizedDateFrom(year: 1900, month: 2, day: 29) == (1900, 3, 1))
		#expect(try CalendarIdentifier.julianGregorian.normalizedDateFrom(year: 1900, month: 2, day: 29) == (1900, 3, 1))

		#expect(try CalendarIdentifier.julian.normalizedDate((1582, 10, 10)) == (1582, 10, 10))
		#expect(try CalendarIdentifier.gregorian.normalizedDate((1582, 10, 10)) == (1582, 10, 10))
		#expect(try CalendarIdentifier.julianGregorian.normalizedDate((1582, 10, 10)) == (1582, 10, 20))

		for calendar in CalendarIdentifier.allCases {
			#expect(try calendar.normalizedDateFrom(year: 2000, month: 13, day: 1) == (2001, 1, 1))
			#expect(try calendar.normalizedDateFrom(year: 2000, month: 1, day: 0) == (1999, 12, 31))
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func errors(_ calendar: CalendarIdentifier) {
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.julianDayNumberFrom(year: .max, month: 1, day: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.julianDayNumberFrom(year: .min, month: 1, day: 1) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.normalizedDateFrom(year: .max, month: 1, day: 1) }
		#expect(throws: CalendarError.invalidDate) { try calendar.numberOfDaysIn(month: 0, year: 2000) }
		#expect(throws: CalendarError.invalidDate) { try calendar.numberOfDaysIn(month: 13, year: 2000) }
		#expect(throws: CalendarError.invalidDate) { try calendar.dayOfYearFrom(year: 2001, month: 2, day: 29) }
		#expect(throws: CalendarError.invalidDate) { try calendar.dateFrom(year: 2001, dayOfYear: 0) }
		#expect(throws: CalendarError.invalidDate) { try calendar.dateFrom(year: 2001, dayOfYear: 366) }
		#expect(throws: CalendarError.invalidDate) { try calendar.decimalYearFrom(year: 2001, month: 2, day: 29) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.dateFromDecimalYear(.nan) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.dateFromDecimalYear(.infinity) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.dateFromDecimalYear(-.infinity) }
		#expect(throws: CalendarError.invalidDecimalYear) { try calendar.dateFromDecimalYear(1e300) }
		#expect(throws: CalendarError.invalidDecimalYear) { try calendar.dateFromDecimalYear(-1e300) }
		#expect(throws: CalendarError.nonFiniteValue) { try calendar.julianDayNumberFromDecimalYear(.nan) }
		#expect(throws: CalendarError.invalidDecimalYear) { try calendar.julianDayNumberFromDecimalYear(1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try calendar.julianDayNumberFromDecimalYear(1e18) }
	}
}
