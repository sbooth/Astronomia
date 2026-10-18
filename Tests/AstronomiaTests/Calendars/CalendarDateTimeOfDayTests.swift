//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct CalendarDateTimeOfDayTests {
	@Test func components() throws {
		let date = try CalendarDate(year: 2026, month: 10, day: 16, hour: 13, minute: 45, second: 30.25, .gregorian)
		#expect(date.year == 2026 && date.month == 10 && date.day == 16)
		#expect(date.fractionSinceMidnight == 49_530.25 / 86_400)
		#expect(date.hour == 13 && date.minute == 45)
		#expect(abs(date.second - 30.25) <= 1e-9)
		#expect(date.timeOfDay.hour == date.hour)

		let noon = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: 0.5, .gregorian)
		try #expect(noon.timeOfDay == TimeOfDay(hour: 12, minute: 0, second: 0))
		let midnight = try CalendarDate(year: 2000, month: 1, day: 1, .gregorian)
		try #expect(midnight.timeOfDay == TimeOfDay(hour: 0, minute: 0, second: 0))
	}

	@Test func lastInstantOfDay() throws {
		// The largest fraction below 1 does not round up to 24:00:00.
		let date = try CalendarDate(year: 2000, month: 1, day: 1, fractionSinceMidnight: Double(1).nextDown, .gregorian)
		#expect(date.hour == 23 && date.minute == 59)
		#expect(date.second < 60 && date.second > 59.999_999)

		// Nor does a time just below midnight become a fraction of 1.
		let late = try CalendarDate(year: 2000, month: 1, day: 1, hour: 23, minute: 59, second: Double(60).nextDown, .gregorian)
		#expect(late.fractionSinceMidnight < 1)
	}

	@Test(arguments: [(0, 0, 0.0), (6, 30, 15.5), (12, 0, 0), (18, 59, 59.123_456), (23, 59, 59.999_999)])
	func roundTrip(hour: Int, minute: Int, second: Double) throws {
		let date = try CalendarDate(year: 1999, month: 12, day: 31, hour: hour, minute: minute, second: second, .julianGregorian)
		#expect(date.hour == hour && date.minute == minute)
		// A fraction resolves about 10 ps over a day.
		#expect(abs(date.second - second) <= 1e-10)
	}

	@Test func errors() throws {
		#expect(throws: CalendarError.invalidTimeOfDay) {
			try CalendarDate(year: 2016, month: 12, day: 31, hour: 23, minute: 59, second: 60, .gregorian)
		}
		#expect(throws: CalendarError.invalidTimeOfDay) {
			try CalendarDate(year: 2026, month: 1, day: 1, hour: 24, minute: 0, .gregorian)
		}
		#expect(throws: CalendarError.nonFiniteValue) {
			try CalendarDate(year: 2026, month: 1, day: 1, hour: 12, minute: 0, second: .nan, .gregorian)
		}
		#expect(throws: CalendarError.invalidDate) {
			try CalendarDate(year: 2026, month: 2, day: 30, hour: 12, minute: 0, .gregorian)
		}
		let leap = try TimeOfDay(hour: 23, minute: 59, second: 60)
		#expect(throws: CalendarError.invalidTimeOfDay) {
			try CalendarDate(calendarDay: CalendarDay(year: 2016, month: 12, day: 31, .gregorian), timeOfDay: leap)
		}
	}

	@Test func julianDate() throws {
		// 2000-01-01T12:00:00 is J2000.0 as a Julian Date.
		#expect(try JulianDate.J2000.calendarDate.timeOfDay == TimeOfDay(hour: 12, minute: 0))
	}
}
