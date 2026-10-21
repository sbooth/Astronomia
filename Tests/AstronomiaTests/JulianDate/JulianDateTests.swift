//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct JulianDateTests {
	// MARK: - Epochs

	@Test func epochs() {
		#expect(JulianDate.J2000.julianDayNumber == 2_451_545)
		#expect(JulianDate.J2000.fractionFromNoon == 0)
		#expect(JulianDate.J2000.julianDate == 2_451_545.0)

		#expect(JulianDate.MJD0.julianDayNumber == 2_400_001)
		#expect(JulianDate.MJD0.fractionFromNoon == -0.5)
		#expect(JulianDate.MJD0.julianDate == 2_400_000.5)
		#expect(JulianDate.MJD0.modifiedJulianDate == 0)

		#expect(JulianDate.B1900.julianDayNumber == 2_415_020)
		#expect(JulianDate.B1900.fractionFromNoon == 0.313_52)
		#expect(JulianDate.B1900.julianDate == 2_415_020.313_52)
	}

	// MARK: - Creation

	@Test func initFromDayNumberAndFraction() throws {
		let date = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		#expect(date.julianDayNumber == 2_451_545)
		#expect(date.fractionFromNoon == 0.25)
		#expect(try JulianDate(julianDayNumber: 2_451_545) == JulianDate.J2000)
	}

	@Test func fractionFromNoonIsNormalized() throws {
		// Whole days carry into the Julian day number
		#expect(try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 1.25) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: 0.25))
		#expect(try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.75) == JulianDate(julianDayNumber: 2_451_544, fractionFromNoon: 0.25))
		#expect(try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -10) == JulianDate(julianDayNumber: 2_451_535))

		// The fraction lies in [-0.5, 0.5), so +0.5 belongs to the next day
		let midnight = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.5)
		#expect(midnight.julianDayNumber == 2_451_546)
		#expect(midnight.fractionFromNoon == -0.5)
		let sameMidnight = try JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: -0.5)
		#expect(sameMidnight == midnight)

		let negativeZero = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.0)
		#expect(negativeZero.fractionFromNoon.sign == .plus)
		#expect(negativeZero == JulianDate.J2000)
	}

	@Test func initFromDayNumberAndFractionErrors() {
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(julianDayNumber: 0, fractionFromNoon: .nan) }
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(julianDayNumber: 0, fractionFromNoon: .infinity) }
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(julianDayNumber: 0, fractionFromNoon: -.infinity) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .max, fractionFromNoon: 0.5) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .min, fractionFromNoon: -0.75) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: 0, fractionFromNoon: 1e300) }
	}

	@Test func extremeDayNumbers() throws {
		let last = try JulianDate(julianDayNumber: .max, fractionFromNoon: 0.25)
		#expect(last.julianDayNumber == .max)
		#expect(last.fractionFromNoon == 0.25)
		let first = try JulianDate(julianDayNumber: .min, fractionFromNoon: -0.5)
		#expect(first.julianDayNumber == .min)
		#expect(first.fractionFromNoon == -0.5)
		// A whole day out of range is recovered by an opposite fraction
		#expect(try JulianDate(julianDayNumber: .max, fractionFromNoon: -1).julianDayNumber == .max - 1)
	}

	@Test func representableBounds() throws {
		#expect(JulianDate.min.julianDayNumber == .min)
		#expect(JulianDate.min.fractionFromNoon == -0.5)
		#expect(JulianDate.max.julianDayNumber == .max)
		#expect(JulianDate.max.fractionFromNoon == Double(0.5).nextDown)
		#expect(JulianDate.min < JulianDate.max)

		// Every other date lies between them
		for date in [JulianDate.J2000, JulianDate.MJD0, JulianDate.B1900] {
			#expect(JulianDate.min < date && date < JulianDate.max)
		}
		#expect(try JulianDate.min.adding(days: 0.25) > JulianDate.min)
		#expect(try JulianDate.max.adding(days: -0.25) < JulianDate.max)

		// Nothing lies a day beyond them
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate.min.adding(days: -1) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate.max.adding(days: 1) }
	}

	@Test func initFromTwoParts() throws {
		#expect(try JulianDate(jd1: 2_451_545) == JulianDate.J2000)
		#expect(try JulianDate(jd1: 2_451_545, jd2: 0.25) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25))
		#expect(try JulianDate(jd1: 2_451_545.5, jd2: 0) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: -0.5))
		#expect(try JulianDate(jd1: 2_400_000.5, jd2: 51_544.5) == JulianDate.J2000)
		#expect(try JulianDate(jd1: 2_451_544.5, jd2: 0.75) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25))
		#expect(try JulianDate(jd1: 0.25, jd2: 2_451_545) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25))

		// The parts are combined without rounding their sum
		let precise = try JulianDate(jd1: 2_451_545, jd2: 1e-12)
		#expect(precise.julianDayNumber == 2_451_545)
		#expect(precise.fractionFromNoon == 1e-12)
		#expect(try JulianDate(julianDate: 2_451_545 + 1e-12).fractionFromNoon != 1e-12)

		// Large parts that cancel exactly
		#expect(try JulianDate(jd1: 1e300, jd2: -1e300) == JulianDate(julianDayNumber: 0))

		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(jd1: .nan, jd2: 0) }
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(jd1: 0, jd2: .infinity) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(jd1: 1e300) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(jd1: .greatestFiniteMagnitude, jd2: .greatestFiniteMagnitude) }
	}

	@Test func initFromSingleValue() throws {
		#expect(try JulianDate(julianDate: 2_451_545) == JulianDate.J2000)
		#expect(try JulianDate(julianDate: 2_451_545.25) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25))
		#expect(try JulianDate(julianDate: 2_451_544.75) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.25))
		#expect(try JulianDate(julianDate: 0) == JulianDate(julianDayNumber: 0))
		#expect(try JulianDate(julianDate: -0.5) == JulianDate(julianDayNumber: 0, fractionFromNoon: -0.5))
		#expect(try JulianDate(julianDate: -0.75) == JulianDate(julianDayNumber: -1, fractionFromNoon: 0.25))
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(julianDate: .nan) }
	}

	@Test func initFromModifiedJulianDate() throws {
		#expect(try JulianDate(modifiedJulianDate: 0) == JulianDate.MJD0)
		#expect(try JulianDate(modifiedJulianDate: 51_544.5) == JulianDate.J2000)
		#expect(try JulianDate(mjd1: 51_544, mjd2: 0.5) == JulianDate.J2000)
		#expect(try JulianDate(mjd1: 51_544, mjd2: 0.75) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25))
		#expect(try JulianDate(mjd1: -2_400_000.5) == JulianDate(julianDayNumber: 0))
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(modifiedJulianDate: .infinity) }
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(mjd1: 0, mjd2: .nan) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(modifiedJulianDate: 1e300) }
	}

	@Test func initFromDaysSinceJ2000() throws {
		#expect(try JulianDate(daysSinceJ2000: 0) == JulianDate.J2000)
		#expect(try JulianDate(daysSinceJ2000: 1.25) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: 0.25))
		#expect(try JulianDate(daysSinceJ2000: -36_525) == JulianDate(julianDayNumber: 2_415_020))
		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(daysSinceJ2000: .nan) }
	}

	@Test func julianEpoch() throws {
		#expect(try JulianDate(julianEpoch: 2000) == JulianDate.J2000)
		#expect(try JulianDate(julianEpoch: 1900) == JulianDate(julianDayNumber: 2_415_020))
		// 0.5 Julian years is 182.625 days
		let midYear = try JulianDate(julianEpoch: 2000.5)
		#expect(midYear == (try JulianDate(julianDayNumber: 2_451_728, fractionFromNoon: -0.375)))

		#expect(JulianDate.J2000.julianEpoch == 2000)
		#expect(midYear.julianEpoch == 2000.5)
		#expect(try JulianDate(julianDayNumber: 2_415_020).julianEpoch == 1900)

		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(julianEpoch: .nan) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianEpoch: 1e300) }
	}

	@Test func besselianEpoch() throws {
		#expect(try JulianDate(besselianEpoch: 1900) == JulianDate.B1900)
		#expect(JulianDate.B1900.besselianEpoch == 1900)

		// B1950.0 is JD 2433282.42345905
		let b1950 = try JulianDate(besselianEpoch: 1950)
		#expect(b1950.julianDayNumber == 2_433_282)
		#expect(b1950.isApproximatelyEqual(to: try JulianDate(jd1: 2_433_282, jd2: 0.423_459_05), toleranceSeconds: 1e-3))
		#expect(b1950.besselianEpoch == 1950)

		#expect(throws: JulianDateError.nonFiniteValue) { try JulianDate(besselianEpoch: -.infinity) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(besselianEpoch: 1e300) }
	}

	// MARK: - Properties

	@Test func singleValueProperties() throws {
		let date = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		#expect(date.julianDate == 2_451_545.25)
		#expect(date.modifiedJulianDate == 51_544.75)
		#expect(date.daysSinceJ2000 == 0.25)
		#expect(date.fractionSinceMidnight == 0.75)

		let before = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.25)
		#expect(before.julianDate == 2_451_544.75)
		#expect(before.modifiedJulianDate == 51_544.25)
		#expect(before.daysSinceJ2000 == -0.25)
		#expect(before.fractionSinceMidnight == 0.25)

		#expect(JulianDate.MJD0.fractionSinceMidnight == 0)
		#expect(JulianDate.MJD0.daysSinceJ2000 == -51_544.5)
	}

	@Test func julianCenturies() throws {
		#expect(JulianDate.J2000.julianCenturiesSinceJ2000 == 0)
		#expect(try JulianDate(julianDayNumber: 2_451_545 + 36_525).julianCenturiesSinceJ2000 == 1)
		#expect(try JulianDate(julianDayNumber: 2_451_545 - 36_525).julianCenturiesSinceJ2000 == -1)
		#expect(try JulianDate(daysSinceJ2000: 36_525 / 2).julianCenturiesSinceJ2000 == 0.5)
	}

	@Test func fractionSinceMidnightIsClampedBelowOne() throws {
		// Just before midnight, fractionFromNoon + 0.5 rounds to 1
		let date = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: Double(0.5).nextDown)
		#expect(date.julianDayNumber == 2_451_545)
		#expect(date.fractionSinceMidnight == Double(1).nextDown)
		#expect(date.parts(using: .dateAndTime).jd2 == Double(1).nextDown)
		#expect(date.parts(using: .dayAndFractionFromMJD0).jd2 == Double(1).nextDown)
		let calendarDate = date.calendarDate(in: .gregorian)
		#expect(calendarDate.calendarDay == (try CalendarDay(year: 2000, month: 1, day: 1, calendar: .gregorian)))
		#expect(calendarDate.fractionSinceMidnight == Double(1).nextDown)
	}

	@Test func propertiesAtExtremes() throws {
		let last = try JulianDate(julianDayNumber: .max, fractionFromNoon: 0.25)
		let first = try JulianDate(julianDayNumber: .min, fractionFromNoon: -0.25)
		#expect(last.julianDate.isFinite)
		#expect(last.modifiedJulianDate.isFinite)
		#expect(last.daysSinceJ2000 > 0)
		#expect(first.daysSinceJ2000 < 0)
		#expect(first.besselianEpoch < 0)
		#expect(last.julianEpoch > 0)
	}

	@Test func differenceAsDouble() {
		#expect(Astronomia.differenceAsDouble(5, 3) == 2)
		#expect(Astronomia.differenceAsDouble(3, 5) == -2)
		#expect(Astronomia.differenceAsDouble(.max, 0) == Double(Int.max))
		// The exact difference overflows Int and is rounded once
		#expect(Astronomia.differenceAsDouble(.max, -1) == 0x1p63)
		#expect(Astronomia.differenceAsDouble(.max, .min) == 0x1p64)
		#expect(Astronomia.differenceAsDouble(.min, .max) == -0x1p64)
		#expect(Astronomia.differenceAsDouble(.min, 1) == -0x1p63)
	}

	// MARK: - Split Methods

	@Test func parts() throws {
		let date = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		#expect(date.parts(using: .julianDate) == (2_451_545.25, 0))
		#expect(date.parts(using: .j2000) == (2_451_545, 0.25))
		#expect(date.parts(using: .mjd) == (2_400_000.5, 51_544.75))
		#expect(date.parts(using: .dateAndTime) == (2_451_544.5, 0.75))
		#expect(date.parts(using: .dayAndFraction) == (2_451_545, 0.25))
		#expect(date.parts(using: .dayAndFractionFromJ2000) == (0, 0.25))
		#expect(date.parts(using: .dayAndFractionFromMJD0) == (51_544, 0.75))

		let before = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.25)
		#expect(before.parts(using: .julianDate) == (2_451_544.75, 0))
		#expect(before.parts(using: .dateAndTime) == (2_451_544.5, 0.25))
		#expect(before.parts(using: .dayAndFraction) == (2_451_545, -0.25))
		#expect(before.parts(using: .dayAndFractionFromJ2000) == (0, -0.25))
		#expect(before.parts(using: .dayAndFractionFromMJD0) == (51_544, 0.25))
	}

	@Test(arguments: [-0.5, -0.375, -0.25, 0, 0.125, 0.25, 0.4375])
	func partsRoundTrip(fractionFromNoon: Double) throws {
		for julianDayNumber in [-1_000_000, 0, 2_400_001, 2_451_545, 5_000_000] {
			let date = try JulianDate(julianDayNumber: julianDayNumber, fractionFromNoon: fractionFromNoon)
			for method in [JulianDate.SplitMethod.julianDate, .j2000, .mjd, .dateAndTime, .dayAndFraction] {
				let (jd1, jd2) = date.parts(using: method)
				#expect(try JulianDate(jd1: jd1, jd2: jd2) == date, "\(method) \(date)")
			}
			let fromJ2000 = date.parts(using: .dayAndFractionFromJ2000)
			#expect(try JulianDate.J2000.adding(days1: fromJ2000.jd1, days2: fromJ2000.jd2) == date)
			let fromMJD0 = date.parts(using: .dayAndFractionFromMJD0)
			#expect(try JulianDate(mjd1: fromMJD0.jd1, mjd2: fromMJD0.jd2) == date)
		}
	}

	// MARK: - Arithmetic

	@Test func addingWholeDays() throws {
		let date = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		#expect(try date.adding(days: 1) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: 0.25))
		#expect(try date.adding(days: -2_451_545) == JulianDate(julianDayNumber: 0, fractionFromNoon: 0.25))
		#expect(try date.adding(days: 0) == date)

		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .max).adding(days: 1) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .min).adding(days: -1) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try date.adding(days: .max) }
	}

	@Test func subtractingWholeDays() throws {
		let date = try JulianDate(julianDayNumber: -2_451_545, fractionFromNoon: 0.25)
		#expect(try date.subtracting(days: 1) == JulianDate(julianDayNumber: -2_451_546, fractionFromNoon: 0.25))
		#expect(try date.subtracting(days: -2_451_545) == JulianDate(julianDayNumber: 0, fractionFromNoon: 0.25))
		#expect(try date.subtracting(days: 0) == date)

		#expect(try JulianDate(julianDayNumber: -1).subtracting(days: .min) == JulianDate(julianDayNumber: .max))
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .max).subtracting(days: -1) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .min).subtracting(days: 1) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: 0).subtracting(days: .min) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try date.subtracting(days: .max) }
	}

	@Test func addingFractionalDays() throws {
		let date = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		#expect(try date.adding(days: 0.25) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: -0.5))
		#expect(try date.adding(days: 1.5) == JulianDate(julianDayNumber: 2_451_547, fractionFromNoon: -0.25))
		#expect(try date.adding(days: -0.75) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.5))
		#expect(try date.adding(days: -1.0) == JulianDate(julianDayNumber: 2_451_544, fractionFromNoon: 0.25))
		#expect(try date.adding(days1: 1_000_000, days2: 0.125) == JulianDate(julianDayNumber: 3_451_545, fractionFromNoon: 0.375))
		// The parts need not be split as whole days and remainder
		#expect(try date.adding(days1: 0.375, days2: 0.375) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: 0))

		#expect(throws: JulianDateError.nonFiniteValue) { try date.adding(days: .nan) }
		#expect(throws: JulianDateError.nonFiniteValue) { try date.adding(days1: 1, days2: -.infinity) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try date.adding(days: 1e300) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .max, fractionFromNoon: 0.25).adding(days: 0.25) }
	}

	@Test func addingSeconds() throws {
		let j2000 = JulianDate.J2000
		#expect(try j2000.adding(seconds: 43_200) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: -0.5))
		#expect(try j2000.adding(seconds: 86_400) == JulianDate(julianDayNumber: 2_451_546))
		#expect(try j2000.adding(seconds: -86_400 * 365) == JulianDate(julianDayNumber: 2_451_545 - 365))
		#expect(try j2000.adding(seconds: 21_600.0) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25))
		#expect(try j2000.adding(seconds: -129_600.0) == JulianDate(julianDayNumber: 2_451_544, fractionFromNoon: -0.5))
		#expect(try j2000.adding(seconds: 1).fractionFromNoon == 1.0 / 86_400)
		#expect(try j2000.adding(seconds: -1).fractionFromNoon == -1.0 / 86_400)
		#expect(try j2000.adding(seconds: 0.5).fractionFromNoon == 0.5 / 86_400)
		// Integer and floating-point seconds agree
		for s in [-1_000_000, -86_401, -1, 0, 1, 43_199, 86_399, 1_000_000] {
			#expect(try j2000.adding(seconds: s) == j2000.adding(seconds: Double(s)), "s = \(s)")
		}

		// 10^9 seconds is 11574 days and 2/27 of a day
		let later = try j2000.adding(seconds1: 1e9, seconds2: 1e-7)
		#expect(later.julianDayNumber == 2_463_119)
		#expect(later.isApproximatelyEqual(to: try JulianDate(julianDayNumber: 2_463_119, fractionFromNoon: 2.0 / 27 + 1e-7 / 86_400), toleranceSeconds: 1e-9))

		// Extreme integer seconds do not overflow before conversion to days
		// Int.max seconds is 106751991167300 days and 55807 seconds
		#expect(try j2000.adding(seconds: Int.max).julianDayNumber == 106_751_993_618_846)
		// Int.min seconds is -106751991167300 days and -55808 seconds
		#expect(try j2000.adding(seconds: Int.min).julianDayNumber == -106_751_988_715_756)

		#expect(throws: JulianDateError.nonFiniteValue) { try j2000.adding(seconds: .nan) }
		#expect(throws: JulianDateError.nonFiniteValue) { try j2000.adding(seconds1: 0, seconds2: .infinity) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try j2000.adding(seconds: 1e300) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .max).adding(seconds: 86_400) }
	}

	@Test func subtractingSeconds() throws {
		let j2000 = JulianDate.J2000
		#expect(try j2000.subtracting(seconds: 43_200) == JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.5))
		#expect(try j2000.subtracting(seconds: 86_400) == JulianDate(julianDayNumber: 2_451_544))
		#expect(try j2000.subtracting(seconds: -86_400) == JulianDate(julianDayNumber: 2_451_546))
		#expect(try j2000.subtracting(seconds: 1).fractionFromNoon == -1.0 / 86_400)
		// Subtracting agrees with adding the negation wherever the negation exists
		for s in [-1_000_000, -86_401, -1, 0, 1, 43_199, 86_399, 1_000_000, Int.max] {
			#expect(try j2000.subtracting(seconds: s) == j2000.adding(seconds: -s), "s = \(s)")
		}

		// Int.min seconds cannot be negated, but subtracting it moves forward by 2^63 s, which is
		// 106751991167300 days and 55808 seconds
		let later = try j2000.subtracting(seconds: Int.min)
		#expect(later.julianDayNumber == 106_751_993_618_846)
		#expect(try later.adding(seconds: Int.min).isApproximatelyEqual(to: j2000, toleranceSeconds: 1e-6))

		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate.min.subtracting(seconds: 1) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate.max.subtracting(seconds: -1) }
	}

	@Test func interval() throws {
		let start = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		let end = try start.adding(days: 1.5)
		#expect(try start.interval(to: end).inDays == 1.5)
		#expect(try end.interval(to: start).inDays == -1.5)
		#expect(try start.interval(to: end) == DayInterval(days: 1, fractionalDay: 0.5))
		#expect(try start.interval(to: start) == .zero)
		#expect(try JulianDate.MJD0.interval(to: JulianDate.J2000) == DayInterval(days: 51_544, fractionalDay: 0.5))

		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try JulianDate(julianDayNumber: .min).interval(to: JulianDate(julianDayNumber: .max)) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try JulianDate(julianDayNumber: .max).interval(to: JulianDate(julianDayNumber: .min)) }
	}

	@Test func addingAndSubtractingIntervals() throws {
		let date = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		let interval = try DayInterval(days: 2, fractionalDay: 0.375)
		#expect(try date.adding(interval) == JulianDate(julianDayNumber: 2_451_548, fractionFromNoon: -0.375))
		#expect(try date.subtracting(interval) == JulianDate(julianDayNumber: 2_451_543, fractionFromNoon: -0.125))
		#expect(try date.adding(interval).subtracting(interval) == date)
		#expect(try date.adding(.zero) == date)

		for (days, fraction) in [(0, 0.0), (1, 0.5), (-1, -0.25), (146_097, 0.0625), (-1_000_000, 0.4375)] {
			let other = try date.adding(days1: Double(days), days2: fraction)
			let interval = try date.interval(to: other)
			#expect(try date.adding(interval) == other)
			#expect(try other.subtracting(interval) == date)
		}

		let oneDay = try DayInterval(days: 1)
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .max).adding(oneDay) }
		#expect(throws: JulianDateError.julianDayNumberNotRepresentable) { try JulianDate(julianDayNumber: .min).subtracting(oneDay) }
	}

	// MARK: - Comparison

	@Test func comparison() throws {
		let a = try JulianDate(julianDayNumber: 2_451_544, fractionFromNoon: 0.25)
		let b = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.5)
		let c = JulianDate.J2000
		let d = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		let e = try JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: -0.5)
		#expect(a < b)
		#expect(b < c)
		#expect(c < d)
		#expect(d < e)
		#expect(!(c < c))
		#expect([e, d, c, b, a].sorted() == [a, b, c, d, e])
	}

	@Test func equalityAndHashing() throws {
		let a = try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25)
		let b = try JulianDate(jd1: 2_451_545.25)
		let c = try JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: -0.75)
		#expect(a == b)
		#expect(a == c)
		#expect(a.hashValue == b.hashValue)
		#expect(a != JulianDate.J2000)
		#expect(Set([a, b, c, JulianDate.J2000]).count == 2)
	}

	@Test func isApproximatelyEqual() throws {
		let date = JulianDate.J2000
		let halfDayLater = try date.adding(days: 0.5)
		#expect(date.isApproximatelyEqual(to: date, toleranceSeconds: 0))
		#expect(date.isApproximatelyEqual(to: halfDayLater, toleranceSeconds: 43_200))
		#expect(halfDayLater.isApproximatelyEqual(to: date, toleranceSeconds: 43_200))
		#expect(!date.isApproximatelyEqual(to: halfDayLater, toleranceSeconds: 43_199.999))

		let oneSecondLater = try date.adding(seconds: 1)
		#expect(date.isApproximatelyEqual(to: oneSecondLater, toleranceSeconds: 1.000_001))
		#expect(!date.isApproximatelyEqual(to: oneSecondLater, toleranceSeconds: 0.999))

		// Dates on different computational paths
		#expect(try JulianDate(julianDate: 2_451_545.1).isApproximatelyEqual(to: JulianDate(jd1: 2_451_545, jd2: 0.1), toleranceSeconds: 1e-4))

		// Dates whose interval is not representable
		let first = try JulianDate(julianDayNumber: .min)
		let last = try JulianDate(julianDayNumber: .max)
		#expect(!first.isApproximatelyEqual(to: last, toleranceSeconds: 1))
		#expect(first.isApproximatelyEqual(to: last, toleranceSeconds: .infinity))
	}

	// MARK: - Descriptions

	@Test func descriptions() throws {
		#expect(JulianDate.J2000.description == "JD 2451545")
		#expect(try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25).description == "JD 2451545 + 0.25")
		#expect(try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: -0.25).description == "JD 2451545 - 0.25")
		#expect(JulianDate.MJD0.description == "JD 2400001 - 0.5")
		#expect(try JulianDate(julianDayNumber: -1).description == "JD -1")
		#expect(try JulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 0.25).debugDescription == "JulianDate(julianDayNumber: 2451545, fractionFromNoon: 0.25)")
	}
}

#if canImport(Foundation)

import Foundation

/// An unvalidated Julian Date payload with the same coding keys as `JulianDate`.
private struct RawJulianDate: Encodable {
	let julianDayNumber: Int
	let fractionFromNoon: Double
}

@Suite struct JulianDateCodableTests {
	// MARK: - Coding

	@Test func codableRoundTrip() throws {
		let dates = try [
			JulianDate.J2000,
			JulianDate.MJD0,
			JulianDate.B1900,
			JulianDate(julianDayNumber: .min, fractionFromNoon: -0.5),
			JulianDate(julianDayNumber: .max, fractionFromNoon: Double(0.5).nextDown),
			JulianDate(jd1: 2_451_545, jd2: 1e-12),
		]
		for date in dates {
			let data = try JSONEncoder().encode(date)
			#expect(try JSONDecoder().decode(JulianDate.self, from: data) == date)
		}
	}

	@Test func decodingNormalizesFraction() throws {
		let data = try JSONEncoder().encode(RawJulianDate(julianDayNumber: 2_451_545, fractionFromNoon: 1.25))
		#expect(try JSONDecoder().decode(JulianDate.self, from: data) == JulianDate(julianDayNumber: 2_451_546, fractionFromNoon: 0.25))
	}

	@Test func decodingInvalidValuesThrows() throws {
		let unrepresentable = try JSONEncoder().encode(RawJulianDate(julianDayNumber: .max, fractionFromNoon: 0.75))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(JulianDate.self, from: unrepresentable) }

		let encoder = JSONEncoder()
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
		let decoder = JSONDecoder()
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
		let nonFinite = try encoder.encode(RawJulianDate(julianDayNumber: 2_451_545, fractionFromNoon: .nan))
		#expect(throws: DecodingError.self) { try decoder.decode(JulianDate.self, from: nonFinite) }
	}
}

#endif
