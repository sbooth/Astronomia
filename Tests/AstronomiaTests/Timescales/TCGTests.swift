//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct TCGTests {
	@Test func constants() throws {
		#expect(TCG.rate == 6.969_290_134e-10)
		// T0 is 1977-01-01T00:00:00 TAI expressed in TT.
		#expect(try TCG.epoch.isApproximatelyEqual(to: TAI.toTT(uniformDate(civilDay(1977, 1, 1))), toleranceSeconds: 1e-12))
		#expect(abs(TCG.epoch.julianDate - 2_443_144.500_372_5) <= 1e-9)
	}

	@Test func equalsTTAtEpoch() throws {
		#expect(try TCG.fromTT(TCG.epoch).isApproximatelyEqual(to: TCG.epoch, toleranceSeconds: 1e-12))
		#expect(try TCG.toTT(TCG.epoch).isApproximatelyEqual(to: TCG.epoch, toleranceSeconds: 1e-12))
	}

	@Test func offsetAtJ2000TT() throws {
		// TCG - TT = L_G / (1 - L_G) × (2451545.0 - 2443144.5003725) days at J2000.0 TT.
		let tcg = try Instant<TT>(.J2000).converted(to: TCG.self)
		#expect(try abs(seconds(from: .J2000, to: tcg.julianDate) - 0.505_833_286_021) <= timescaleTolerance)
	}

	@Test func offsetAtJ2000TCG() throws {
		// TCG - TT = L_G × (2451545.0 - 2443144.5003725) days at J2000.0 TCG.
		let tt = try Instant<TCG>(.J2000).converted(to: TT.self)
		#expect(try abs(seconds(from: tt.julianDate, to: .J2000) - 0.505_833_285_669) <= timescaleTolerance)
	}

	@Test func rate() throws {
		// TCG gains L_G / (1 - L_G) × 31,557,600 s ≈ 21.993 ms per Julian year of TT.
		// Compare the offsets rather than the elapsed TCG, which a single Double resolves only
		// to about 4 ns.
		let ttStart = JulianDate.J2000
		let ttEnd = try ttStart.adding(days: 365.25)
		let offsetAtStart = try seconds(from: ttStart, to: TCG.fromTT(ttStart))
		let offsetAtEnd = try seconds(from: ttEnd, to: TCG.fromTT(ttEnd))
		#expect(abs(offsetAtEnd - offsetAtStart - 0.021_993_407_049) <= timescaleTolerance)
	}

	@Test func negativeBeforeEpoch() throws {
		let tt = try uniformDate(civilDay(1950, 1, 1))
		let tcg = try TCG.fromTT(tt)
		#expect(tcg < tt)
	}

	@Test(arguments: sampleDates)
	func roundTrip(date: JulianDate) throws {
		try expectRoundTrip(TCG.self, TT.self, date: date)
		try expectRoundTrip(TT.self, TCG.self, date: date)
		try expectRoundTrip(TCG.self, TAI.self, date: date)
	}

	@Test(arguments: utcSampleDates)
	func roundTripWithUTC(date: JulianDate) throws {
		try expectRoundTrip(UTC.self, TCG.self, date: date)
	}

	@Test func outOfRange() throws {
		// T0 to JDN Int.min is not representable as a day interval.
		let earliest = try JulianDate(julianDayNumber: .min, fractionFromNoon: 0)
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try TCG.fromTT(earliest)
		}
		// The correction near JDN Int.max is about 6 × 10⁹ days, past the end of the range.
		let latest = try JulianDate(julianDayNumber: .max, fractionFromNoon: 0)
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try TCG.fromTT(latest)
		}
	}
}
