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
		#expect(JulianDate(try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)) == JulianDate.J2000)
		#expect(JulianDate(try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, .julian)) == JulianDate.J2000)
		#expect(JulianDate(try CalendarDate(year: 1858, month: 11, day: 17, .gregorian)) == JulianDate.MJD0)
		#expect(JulianDate(try CalendarDate(year: -4712, month: 1, day: 1, fractionSinceMidnight: 0.5, .julian)) == (try JulianDate(julianDayNumber: 0)))
		#expect(JulianDate(try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.75, .gregorian)) == (try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)))
		#expect(JulianDate(try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.25, .gregorian)) == (try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.25)))
	}

	@Test func initFromComponents() throws {
		// The Julian-Gregorian calendar is the default
		#expect(try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5) == JulianDate.J2000)
		#expect(try JulianDate(year: 1858, month: 11, day: 17) == JulianDate.MJD0)
		#expect(try JulianDate(year: -4712, month: 1, day: 1, fractionSinceMidnight: 0.5) == JulianDate(julianDayNumber: 0))
		#expect(try JulianDate(year: 1582, month: 10, day: 4) == JulianDate(julianDayNumber: 2_299_160, fractionFromNoon: -0.5))
		#expect(try JulianDate(year: 1582, month: 10, day: 15) == JulianDate(julianDayNumber: 2_299_161, fractionFromNoon: -0.5))

		#expect(try JulianDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, .julian) == JulianDate.J2000)
		#expect(try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian) == JulianDate.J2000)
		// Valid in the Gregorian calendar but not in the Julian-Gregorian calendar
		#expect(try JulianDate(year: 1582, month: 10, day: 10, .gregorian) == JulianDate(julianDayNumber: 2_299_156, fractionFromNoon: -0.5))
	}

	@Test func initFromComponentsErrors() {
		#expect(throws: CalendarError.invalidDate) { try JulianDate(year: 1582, month: 10, day: 10) }
		#expect(throws: CalendarError.invalidDate) { try JulianDate(year: 1900, month: 2, day: 29, .gregorian) }
		#expect(throws: CalendarError.invalidDayFraction) { try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 1) }
		#expect(throws: CalendarError.invalidDayFraction) { try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: -0.25) }
		#expect(throws: CalendarError.nonFiniteValue) { try JulianDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: .nan) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianDate(year: .max, month: 1, day: 1) }
	}

	@Test func calendarDate() throws {
		#expect(JulianDate.J2000.calendarDate == (try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .julianGregorian)))
		#expect(JulianDate.J2000.calendarDate(.gregorian) == (try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)))
		#expect(JulianDate.J2000.calendarDate(.julian) == (try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, .julian)))
		#expect(JulianDate.MJD0.calendarDate == (try CalendarDate(year: 1858, month: 11, day: 17, .julianGregorian)))
		#expect(try JulianDate(julianDayNumber: 0).calendarDate == CalendarDate(year: -4712, month: 1, day: 1, fractionSinceMidnight: 0.5, .julianGregorian))
		#expect(try JulianDate(julianDayNumber: 0).calendarDate(.gregorian) == CalendarDate(year: -4713, month: 11, day: 24, fractionSinceMidnight: 0.5, .gregorian))

		// Midnight starting October 15, 1582 and the last moments of October 4
		#expect(try JulianDate(julianDate: 2_299_160.5).calendarDate == CalendarDate(year: 1582, month: 10, day: 15, .julianGregorian))
		#expect(try JulianDate(julianDate: 2_299_160.25).calendarDate == CalendarDate(year: 1582, month: 10, day: 4, fractionSinceMidnight: 0.75, .julianGregorian))
	}

	@Test func calendarDateIsOnTheSameDayAsTheJulianDayNumber() throws {
		for calendar in CalendarIdentifier.allCases {
			for fraction in [-0.5, -0.25, 0, 0.25, Double(0.5).nextDown] {
				let date = try JulianDate(julianDayNumber: 2_299_160, fractionFromNoon: fraction)
				let calendarDate = date.calendarDate(calendar)
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
				let calendarDate = CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), uncheckedFractionSinceMidnight: f)
				let julianDate = JulianDate(calendarDate)
				#expect(julianDate.julianDayNumber == J)
				#expect(julianDate.calendarDate(calendar) == calendarDate, "J = \(J), f = \(f)")
			}
		}
	}

	@Test func calendarDateRoundTripBefore0600IsApproximate() throws {
		for f in [0.0, 1e-9, 0.1, 0.2, 0.249_999] {
			let calendarDate = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: f, .gregorian)
			let roundTripped = JulianDate(calendarDate).calendarDate(.gregorian)
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
		#expect(try JulianDate(decimalYear: 2000.5, .gregorian) == JulianDate(year: 2000, month: 7, day: 2, .gregorian))
		#expect(try JulianDate(decimalYear: -0.5, .julian) == JulianDate(year: -1, month: 7, day: 2, fractionSinceMidnight: 0.5, .julian))

		#expect(try JulianDate(year: 1985, month: 7, day: 2, fractionSinceMidnight: 0.5).decimalYear == 1985.5)
		#expect(JulianDate.J2000.decimalYear == (try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .julianGregorian)).decimalYear)
		#expect(JulianDate.J2000.decimalYear(.julian) == (try CalendarDate(year: 1999, month: 12, day: 19, fractionSinceMidnight: 0.5, .julian)).decimalYear)
		#expect(abs(JulianDate.J2000.decimalYear - (2000 + 0.5 / 366)) < 1e-12)
		// The calendars disagree about the decimal year of the same instant
		#expect(JulianDate.J2000.decimalYear(.julian) < JulianDate.J2000.decimalYear(.gregorian))

		#expect(throws: CalendarError.nonFiniteValue) { try JulianDate(decimalYear: .nan) }
		#expect(throws: CalendarError.invalidDecimalYear) { try JulianDate(decimalYear: 1e300) }
		#expect(throws: CalendarError.julianDayNumberNotRepresentable) { try JulianDate(decimalYear: 1e18, .gregorian) }
	}

	@Test(arguments: CalendarIdentifier.allCases)
	func decimalYearRoundTrip(_ calendar: CalendarIdentifier) throws {
		for J in stride(from: 2_200_000, through: 2_500_000, by: 997) {
			for f in [-0.5, -0.25, 0, 0.25, 0.375] {
				let date = try JulianDate(julianDayNumber: J, fractionFromNoon: f)
				let roundTripped = try JulianDate(decimalYear: date.decimalYear(calendar), calendar)
				#expect(roundTripped.isApproximatelyEqual(to: date, toleranceSeconds: 1e-4), "J = \(J), f = \(f)")
			}
		}
	}
}

#if canImport(FoundationEssentials) || canImport(Foundation)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

@Suite struct JulianDateFoundationDateTests {
	@Test func referenceDate() throws {
		let reference = try JulianDate(Date(timeIntervalSinceReferenceDate: 0))
		#expect(reference == JulianDate.referenceDate)
		#expect(reference.julianDate == 2_451_910.5)
		#expect(reference.date == Date(timeIntervalSinceReferenceDate: 0))
	}

	@Test func knownInstants() throws {
		// The Unix epoch, 1970-01-01T00:00:00 UTC, is JD 2440587.5
		#expect(try JulianDate(Date(timeIntervalSince1970: 0)) == JulianDate(julianDayNumber: 2_440_588, fractionFromNoon: -0.5))
		// J2000.0 as a UTC label is 2000-01-01T12:00:00
		#expect(JulianDate.J2000.date.timeIntervalSinceReferenceDate == -31_579_200)
		#expect(try JulianDate(Date(timeIntervalSinceReferenceDate: -31_579_200)) == JulianDate.J2000)
		// MJD zero is 1858-11-17T00:00:00
		#expect(try JulianDate(Date(timeIntervalSince1970: -3_506_716_800)) == JulianDate.MJD0)
		#expect(try JulianDate(Date(timeIntervalSinceReferenceDate: 43_200)) == JulianDate(julianDayNumber: 2_451_911))
	}

	@Test func roundTrip() throws {
		for t in [-1e10, -978_307_200, -1.5, 0, 0.25, 1, 43_200, 86_399.999, 8e8, 1e10] {
			let date = Date(timeIntervalSinceReferenceDate: t)
			let julianDate = try JulianDate(date)
			#expect(abs(julianDate.date.timeIntervalSinceReferenceDate - t) <= max(1e-6, t.ulp), "t = \(t)")
		}
		for days in [-1_000_000, -1, 0, 1, 1_000_000] {
			let julianDate = try JulianDate(julianDayNumber: 2_451_911 + days, fractionFromNoon: -0.5)
			#expect(julianDate.date.timeIntervalSinceReferenceDate == Double(days) * 86_400)
			#expect(try JulianDate(julianDate.date) == julianDate)
		}
	}

	@Test func errors() {
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(Date(timeIntervalSinceReferenceDate: .nan)) }
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(Date(timeIntervalSinceReferenceDate: .infinity)) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(Date(timeIntervalSinceReferenceDate: 1e300)) }
	}
}

#endif
