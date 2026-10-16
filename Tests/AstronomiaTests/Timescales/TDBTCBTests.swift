//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// TDB - TT at 0h TT on a date.
struct TDBReference: Sendable, CustomTestStringConvertible {
	let year: Int
	let month: Int
	let day: Int
	/// The full geocentric Fairhead & Bretagnon series (787 terms plus JPL mass
	/// adjustments), from ERFA's `eraDtdb` with u = v = 0.
	let fullSeries: Double
	/// The seven-term series of USNO Circular 179, equation 2.6.
	let circular179: Double

	var testDescription: String { "\(year)-\(month)-\(day)" }
}

let tdbReferences: [TDBReference] = [
	.init(year: 1650, month: 1, day: 1, fullSeries: 1.329725261e-04, circular179: 1.293468867672e-04),
	.init(year: 1900, month: 1, day: 1, fullSeries: -1.846023201e-05, circular179: -1.841120030059e-05),
	.init(year: 1977, month: 1, day: 1, fullSeries: -6.551401857e-05, circular179: -6.725459324234e-05),
	.init(year: 2000, month: 1, day: 1, fullSeries: -1.137630989e-04, circular179: -1.101395177105e-04),
	.init(year: 2026, month: 10, day: 14, fullSeries: -1.615828249e-03, circular179: -1.615886898667e-03),
	.init(year: 2150, month: 7, day: 1, fullSeries: 1.829281585e-04, circular179: 1.806115267077e-04),
	.init(year: 2199, month: 12, day: 31, fullSeries: -2.302206746e-04, circular179: -2.271570570295e-04),
]

@Suite struct TDBTests {
	@Test func defaultContext() {
		#expect(TDB.defaultContext.model == .usnoCircular179)
		#expect(TDB.Context().model == .usnoCircular179)
	}

	@Test func valueAtJ2000() {
		#expect(abs(TDB.tdbMinusTT(at: .J2000) - -9.575_743_486_095e-5) <= 1e-15)
	}

	@Test(arguments: tdbReferences)
	func circular179Series(reference: TDBReference) throws {
		let tt = try uniformDate(civilDay(reference.year, reference.month, reference.day))
		#expect(abs(TDB.tdbMinusTT(at: tt) - reference.circular179) <= 1e-12)
	}

	@Test(arguments: tdbReferences)
	func withinTenMicrosecondsOfFullSeries(reference: TDBReference) throws {
		let tt = try uniformDate(civilDay(reference.year, reference.month, reference.day))
		#expect(abs(TDB.tdbMinusTT(at: tt) - reference.fullSeries) <= 1e-5)
	}

	@Test func bounded() throws {
		// The annual term dominates, so |TDB - TT| stays below about 1.7 ms.
		let start = try uniformDate(civilDay(1990, 1, 1))
		for step in 0 ..< 3_000 {
			let tt = try start.adding(days: step * 5)
			#expect(abs(TDB.tdbMinusTT(at: tt)) <= 1.7e-3, "\(tt)")
		}
	}

	@Test(arguments: tdbReferences)
	func conversionAppliesSeries(reference: TDBReference) throws {
		let tt = try uniformDate(civilDay(reference.year, reference.month, reference.day))
		let tdb = try Instant<TT>(tt).converted(to: TDB.self)
		#expect(try abs(seconds(from: tt, to: tdb.julianDate) - reference.circular179) <= timescaleTolerance)
	}

	@Test(arguments: tdbReferences)
	func inverseRemovesSeries(reference: TDBReference) throws {
		// TT = TDB - (TDB - TT): converting back must subtract the correction, not add it.
		let tt = try uniformDate(civilDay(reference.year, reference.month, reference.day))
		let tdb = try tt.adding(seconds: reference.circular179)
		let back = try Instant<TDB>(tdb).converted(to: TT.self)
		#expect(back.julianDate.isApproximatelyEqual(to: tt, toleranceSeconds: timescaleTolerance))
	}
	
	@Test(arguments: sampleDates)
	func roundTrip(date: JulianDate) throws {
		try expectRoundTrip(TDB.self, TT.self, date: date)
		try expectRoundTrip(TT.self, TDB.self, date: date)
		try expectRoundTrip(TDB.self, TAI.self, date: date)
	}

	@Test(arguments: utcSampleDates)
	func roundTripWithUTC(date: JulianDate) throws {
		try expectRoundTrip(UTC.self, TDB.self, date: date)
	}
}

@Suite struct TCBTests {
	@Test func constants() {
		#expect(TCB.rate == 1.550_519_768e-8)
		#expect(TCB.tdb0 == -6.55e-5)
		#expect(TCB.epoch == TCG.epoch)
		#expect(TCB.defaultContext == TDB.defaultContext)
	}

	@Test func offsetAtEpoch() throws {
		// At T0 TCB, TDB = T0 + TDB0.
		let tdb = try TCB.toTDB(TCB.epoch)
		#expect(try abs(seconds(from: tdb, to: TCB.epoch) - 6.55e-5) <= 1e-12)
		#expect(try TCB.fromTDB(tdb).isApproximatelyEqual(to: TCB.epoch, toleranceSeconds: 1e-12))
	}

	@Test func agreesWithTTAtEpoch() throws {
		// TDB0 was chosen so that TCB = TT at T0 at the geocenter. The difference is the
		// error of the TDB - TT series, here about 1.7 µs.
		let tcb = try Instant<TT>(TCB.epoch).converted(to: TCB.self)
		#expect(try abs(seconds(from: TCB.epoch, to: tcb.julianDate)) <= 1e-5)
	}

	@Test func offsetAtJ2000TDB() throws {
		// TCB - TDB = -TDB0 + L_B / (1 - L_B) × (J2000.0 - TDB0 - T0) at J2000.0 TDB.
		let tcb = try TCB.fromTDB(.J2000)
		#expect(try abs(seconds(from: .J2000, to: tcb) - 11.253_787_268_249) <= timescaleTolerance)
	}

	@Test func offsetAtJ2000TCB() throws {
		// TCB - TDB = L_B × (J2000.0 - T0) - TDB0 at J2000.0 TCB.
		let tdb = try TCB.toTDB(.J2000)
		#expect(try abs(seconds(from: tdb, to: .J2000) - 11.253_787_093_757) <= timescaleTolerance)
	}

	@Test func offsetAtJ2000TT() throws {
		// TCB - TT at J2000.0 TT, with TDB - TT from the default series.
		let tcb = try Instant<TT>(.J2000).converted(to: TCB.self)
		#expect(try abs(seconds(from: .J2000, to: tcb.julianDate) - 11.253_691_510_813) <= timescaleTolerance)
	}

	@Test func rate() throws {
		// TCB gains L_B / (1 - L_B) × 31,557,600 s ≈ 0.4893 s per Julian year of TDB.
		let tdbStart = JulianDate.J2000
		let tdbEnd = try tdbStart.adding(days: 365.25)
		let offsetAtStart = try seconds(from: tdbStart, to: TCB.fromTDB(tdbStart))
		let offsetAtEnd = try seconds(from: tdbEnd, to: TCB.fromTDB(tdbEnd))
		#expect(abs(offsetAtEnd - offsetAtStart - 0.489_306_833_893) <= timescaleTolerance)
	}

	@Test(arguments: sampleDates)
	func tdbRoundTrip(date: JulianDate) throws {
		#expect(try TCB.toTDB(TCB.fromTDB(date)).isApproximatelyEqual(to: date, toleranceSeconds: timescaleTolerance))
		#expect(try TCB.fromTDB(TCB.toTDB(date)).isApproximatelyEqual(to: date, toleranceSeconds: timescaleTolerance))
	}

	@Test(arguments: sampleDates)
	func roundTrip(date: JulianDate) throws {
		try expectRoundTrip(TCB.self, TT.self, date: date)
		try expectRoundTrip(TT.self, TCB.self, date: date)
		try expectRoundTrip(TCB.self, TDB.self, date: date)
		try expectRoundTrip(TCB.self, TCG.self, date: date)
	}

	@Test(arguments: utcSampleDates)
	func roundTripWithUTC(date: JulianDate) throws {
		try expectRoundTrip(UTC.self, TCB.self, date: date)
	}

	@Test func outOfRange() throws {
		// T0 to JDN Int.min is not representable as a day interval.
		let earliest = try JulianDate(julianDayNumber: .min, fractionFromNoon: 0)
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try TCB.toTDB(earliest)
		}
		// The correction near JDN Int.max is about 1.4 × 10¹¹ days, past the end of the range.
		let latest = try JulianDate(julianDayNumber: .max, fractionFromNoon: 0)
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try TCB.fromTDB(latest)
		}
	}
}
