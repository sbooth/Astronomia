//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct InstantTests {
	@Test(arguments: sampleDates)
	func sameTimescale(date: JulianDate) throws {
		let tai = try Instant<TAI>(date).converted(to: TAI.self)
		#expect(tai.julianDate.isApproximatelyEqual(to: date, toleranceSeconds: timescaleTolerance))
		let tt = try Instant<TT>(date).converted(to: TT.self)
		#expect(tt.julianDate == date)
	}

	@Test(arguments: utcSampleDates)
	func sameTimescaleUTC(date: JulianDate) throws {
		let utc = try Instant<UTC>(date).converted(to: UTC.self)
		#expect(utc.julianDate.isApproximatelyEqual(to: date, toleranceSeconds: timescaleTolerance))
	}

	@Test func chainedConversions() throws {
		// UTC → GPS → TT → TAI → UTC through the 2016 leap second.
		let utc = try Instant<UTC>(utcDate(civilDay(2016, 12, 31), seconds: 86_400.25))
		let back = try utc
			.converted(to: GPS.self)
			.converted(to: TT.self)
			.converted(to: TAI.self)
			.converted(to: UTC.self)
		#expect(back.julianDate.julianDayNumber == utc.julianDate.julianDayNumber)
		#expect(try abs(clockReading(back.julianDate) - 86_400.25) <= timescaleTolerance)
	}

	@Test func comparable() throws {
		let earlier = Instant<TT>(.J2000)
		let later = try Instant<TT>(JulianDate.J2000.adding(seconds: 1))
		#expect(earlier < later)
		#expect(!(later < earlier))
		#expect(earlier == Instant<TT>(.J2000))
	}

	@Test func description() {
		#expect(Instant<TT>(.J2000).description == "\(JulianDate.J2000) TT")
		#expect(Instant<UTC>(.J2000).description.hasSuffix(" UTC"))
		#expect(Instant<GPS>(.J2000).description.hasSuffix(" GPS"))
	}
}

#if canImport(Foundation)

import Foundation

@Suite struct InstantCodableTests {
	@Test(arguments: sampleDates)
	func codable(date: JulianDate) throws {
		let instant = Instant<TAI>(date)
		let data = try JSONEncoder().encode(instant)
		#expect(try JSONDecoder().decode(Instant<TAI>.self, from: data) == instant)
		// The timescale is not encoded, so the same data decodes as a bare Julian Date.
		#expect(try JSONDecoder().decode(JulianDate.self, from: data) == date)
	}
}

#endif
