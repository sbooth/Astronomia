//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct JulianDateCalendarDateTests {
	@Test func initFromCalendarDate() throws {
		#expect(JulianDate(try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: .gregorian)) == JulianDate.j2000)
		#expect(JulianDate(try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, calendar: .julian)) == JulianDate.j2000)
		#expect(JulianDate(try CalendarDate(year: 1858, month: 11, day: 17, calendar: .gregorian)) == JulianDate.mjd0)
		#expect(JulianDate(try CalendarDate(year: -4712, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: .julian)) == (try JulianDate(julianDayNumber: 0)))
		#expect(JulianDate(try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.75, calendar: .gregorian)) == (try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)))
		#expect(JulianDate(try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, calendar: .gregorian)) == (try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.25)))
	}

	@Test func initFromComponents() throws {
		// The Julian-Gregorian calendar is the default
		#expect(try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5) == JulianDate.j2000)
		#expect(try JulianDate(year: 1858, month: 11, day: 17) == JulianDate.mjd0)
		#expect(try JulianDate(year: -4712, month: 1, day: 1, fractionSinceMidnight: 0.5) == JulianDate(julianDayNumber: 0))
		#expect(try JulianDate(year: 1582, month: 10, day: 4) == JulianDate(julianDayNumber: 2_299_160, fractionFromNoon: -0.5))
		#expect(try JulianDate(year: 1582, month: 10, day: 15) == JulianDate(julianDayNumber: 2_299_161, fractionFromNoon: -0.5))

		#expect(try JulianDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, calendar: .julian) == JulianDate.j2000)
		#expect(try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: .gregorian) == JulianDate.j2000)
		// Valid in the Gregorian calendar but not in the Julian-Gregorian calendar
		#expect(try JulianDate(year: 1582, month: 10, day: 10, calendar: .gregorian) == JulianDate(julianDayNumber: 2_299_156, fractionFromNoon: -0.5))
	}

	@Test func initFromComponentsErrors() {
		#expect(throws: CalendarError.invalidDate) { try JulianDate(year: 1582, month: 10, day: 10) }
		#expect(throws: CalendarError.invalidDate) { try JulianDate(year: 1900, month: 2, day: 29, calendar: .gregorian) }
		#expect(throws: CalendarError.invalidDayFraction) { try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 1) }
		#expect(throws: CalendarError.invalidDayFraction) { try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: -0.25) }
		#expect(throws: CalendarError.nonFiniteValue) { try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: .nan) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianDate(year: .max, month: 1, day: 1) }
	}

	@Test func calendarDate() throws {
		#expect(JulianDate.j2000.calendarDate == (try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: .julianGregorian)))
		#expect(JulianDate.j2000.calendarDate(in: .gregorian) == (try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: .gregorian)))
		#expect(JulianDate.j2000.calendarDate(in: .julian) == (try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, calendar: .julian)))
		#expect(JulianDate.mjd0.calendarDate == (try CalendarDate(year: 1858, month: 11, day: 17, calendar: .julianGregorian)))
		#expect(try JulianDate(julianDayNumber: 0).calendarDate == CalendarDate(year: -4712, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: .julianGregorian))
		#expect(try JulianDate(julianDayNumber: 0).calendarDate(in: .gregorian) == CalendarDate(year: -4713, month: 11, day: 24, fractionSinceMidnight: 0.5, calendar: .gregorian))

		// Midnight starting October 15, 1582 and the last moments of October 4
		#expect(try JulianDate(julianDate: 2_299_160.5).calendarDate == CalendarDate(year: 1582, month: 10, day: 15, calendar: .julianGregorian))
		#expect(try JulianDate(julianDate: 2_299_160.25).calendarDate == CalendarDate(year: 1582, month: 10, day: 4, fractionSinceMidnight: 0.75, calendar: .julianGregorian))
	}

	@Test func calendarDateIsOnTheSameDayAsTheJulianDayNumber() throws {
		for calendar in CalendarIdentifier.allCases {
			for fraction in [-0.5, -0.25, 0, 0.25, Double(0.5).nextDown] {
				let date = try JulianDate(julianDayNumber: 2_299_160, fractionFromNoon: fraction)
				let calendarDate = date.calendarDate(in: calendar)
				#expect(calendarDate.julianDayNumber == 2_299_160)
				#expect(calendarDate.calendar == calendar)
				#expect(calendarDate.fractionSinceMidnight >= 0 && calendarDate.fractionSinceMidnight < 1)
			}
		}
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func calendarDateRoundTrip(_ calendar: CalendarIdentifier) throws {
		// Times of day from 06:00 convert exactly
		let fractions = [0.25, 0.375, 0.5, 0.75, 0.9375, Double(1).nextDown]
		for J in stride(from: 2_298_000, through: 2_301_000, by: 7) {
			for f in fractions {
				let calendarDate = CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar: calendar), uncheckedFractionSinceMidnight: f)
				let julianDate = JulianDate(calendarDate)
				#expect(julianDate.julianDayNumber == J)
				#expect(julianDate.calendarDate(in: calendar) == calendarDate, "J = \(J), f = \(f)")
			}
		}
	}

	@Test func calendarDateRoundTripBefore0600IsApproximate() throws {
		for f in [0.0, 1e-9, 0.1, 0.2, 0.249_999] {
			let calendarDate = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: f, calendar: .gregorian)
			let roundTripped = JulianDate(calendarDate).calendarDate(in: .gregorian)
			#expect(roundTripped.calendarDay == calendarDate.calendarDay)
			#expect(abs(roundTripped.fractionSinceMidnight - f) <= 0x1p-54, "f = \(f)")
		}
	}

	@Test func decimalYear() throws {
		// 1985.5 is noon on July 2, 1985
		#expect(try JulianDate(decimalYear: 1985.5) == JulianDate(year: 1985, month: 7, day: 2, fractionSinceMidnight: 0.5))
		#expect(try JulianDate(decimalYear: 1985.5).julianDate == 2_446_249)
		#expect(try JulianDate(decimalYear: 2000) == JulianDate(year: 2000, month: 1, day: 1))
		#expect(try JulianDate(decimalYear: 1582 + 277.0 / 355) == JulianDate(year: 1582, month: 10, day: 15))
		#expect(try JulianDate(decimalYear: 2000.5, calendar: .gregorian) == JulianDate(year: 2000, month: 7, day: 2, calendar: .gregorian))
		#expect(try JulianDate(decimalYear: -0.5, calendar: .julian) == JulianDate(year: -1, month: 7, day: 2, fractionSinceMidnight: 0.5, calendar: .julian))

		#expect(try JulianDate(year: 1985, month: 7, day: 2, fractionSinceMidnight: 0.5).decimalYear == 1985.5)
		#expect(JulianDate.j2000.decimalYear == (try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, calendar: .julianGregorian)).decimalYear)
		#expect(JulianDate.j2000.decimalYear(in: .julian) == (try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, calendar: .julian)).decimalYear)
		#expect(abs(JulianDate.j2000.decimalYear - (2000 + 0.5 / 366)) < 1e-12)
		// The calendars disagree about the decimal year of the same instant
		#expect(JulianDate.j2000.decimalYear(in: .julian) < JulianDate.j2000.decimalYear(in: .gregorian))

		#expect(throws: CalendarError.nonFiniteValue) { try JulianDate(decimalYear: .nan) }
		#expect(throws: CalendarError.invalidDecimalYear) { try JulianDate(decimalYear: 1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianDate(decimalYear: 1e18, calendar: .gregorian) }
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func decimalYearRoundTrip(_ calendar: CalendarIdentifier) throws {
		for J in stride(from: 2_200_000, through: 2_500_000, by: 997) {
			for f in [-0.5, -0.25, 0, 0.25, 0.375] {
				let date = try JulianDate(julianDayNumber: J, fractionFromNoon: f)
				let roundTripped = try JulianDate(decimalYear: date.decimalYear(in: calendar), calendar: calendar)
				#expect(roundTripped.isApproximatelyEqual(to: date, toleranceSeconds: 1e-4), "J = \(J), f = \(f)")
			}
		}
	}
}
