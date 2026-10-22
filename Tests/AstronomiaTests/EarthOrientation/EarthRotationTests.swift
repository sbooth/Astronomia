//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct EarthRotationTests {
	@Test func sofaReferenceValues() throws {
		// The IAU SOFA test suite: iauEra00(2400000.5, 54388.0) and
		// iauGmst06(2400000.5, 53736.0, 2400000.5, 53736.0), each to 1e-12 rad
		let era = EarthRotation.earthRotationAngle(ut1: try JulianDate(jd1: 2_400_000.5, jd2: 54_388))
		#expect(abs(era.radians - 0.402_283_724_002_815_810_2) <= 1e-12)
		let date = try JulianDate(jd1: 2_400_000.5, jd2: 53_736)
		let gmst = EarthRotation.greenwichMeanSiderealTime(ut1: date, tt: date)
		#expect(abs(gmst.radians - 1.754_174_971_870_091_203) <= 1e-12)
	}

	@Test(arguments: [
		// Julian day number, fraction from noon, ERA and GMST from ERFA (SOFA) with
		// TT - UT1 = 69.2 s, from 1600 to 3000
		(2_451_545, 0.0, 4.894_961_212_823_756, 4.894_961_283_641_151),
		(2_460_600, 0.25, 5.156_161_458_854_775_5, 5.161_705_509_108_325),
		(2_378_497, -0.5, 1.797_015_292_959_656_6, 1.752_322_533_229_476_5),
		(2_816_788, -0.5, 1.535_134_890_604_752, 1.759_407_186_663_585_4),
		(2_305_448, 0.123_456, 5.760_075_317_840_233, 5.670_743_741_114_964),
	])
	func agreesWithSOFA(julianDayNumber: Int, fractionFromNoon: Double, era: Double, gmst: Double) throws {
		let ut1 = try JulianDate(julianDayNumber: julianDayNumber, fractionFromNoon: fractionFromNoon)
		let tt = try ut1.adding(seconds: 69.2)
		#expect(abs(EarthRotation.earthRotationAngle(ut1: ut1).radians - era) <= 1e-12)
		#expect(abs(EarthRotation.greenwichMeanSiderealTime(ut1: ut1, tt: tt).radians - gmst) <= 1e-12)
	}

	@Test func angleAtJ2000AndRate() throws {
		let j2000 = Instant<UT1>(.J2000)
		#expect(abs(EarthRotation.angle(at: j2000).radians - 0.779_057_273_264 * 2 * .pi) <= 1e-15)

		// A UT1 day later, Earth has turned 1.00273781191135448 times.
		let nextDay = try Instant<UT1>(JulianDate.J2000.adding(days: 1))
		let advance = (EarthRotation.angle(at: nextDay) - EarthRotation.angle(at: j2000)).normalized()
		#expect(abs(advance.radians - 0.002_737_811_911_354_48 * 2 * .pi) <= 1e-12)
	}

	@Test func classicGMSTAtJ2000() throws {
		// At 2000-01-01T12:00:00 UT1, GMST is about 18.697375 hours.
		let earthOrientation = EarthOrientation(ut1: UT1.Context(deltaT: DeltaTFunction.constant(64.184)))
		let gmst = try EarthRotation.greenwichMeanSiderealTime(at: Instant<UT1>(.J2000), earthOrientation: earthOrientation)
		#expect(abs(gmst.hours - 18.697_374_828_702_76) <= 1e-10)
	}

	@Test func instantsAgree() throws {
		// From a TT instant or the same UT1 instant, GMST is the same.
		let context = UT1.Context(deltaT: DeltaTFunction.constant(69.2))
		let tt = try Instant<TT>(JulianDate(julianDayNumber: 2_460_600, fractionFromNoon: 0.25))
		let ut1 = try tt.converted(to: UT1.self, targetContext: context)
		let earthOrientation = EarthOrientation(ut1: context)
		let fromTT = try EarthRotation.greenwichMeanSiderealTime(at: tt, earthOrientation: earthOrientation)
		let fromUT1 = try EarthRotation.greenwichMeanSiderealTime(at: ut1, earthOrientation: earthOrientation)
		#expect(abs((fromTT - fromUT1).normalizedSigned().radians) <= 1e-12)
		// In any timescale, and from a UT1 instant with a UT1 context as its timescale context
		let fromTDB = try EarthRotation.greenwichMeanSiderealTime(at: tt.converted(to: TDB.self), earthOrientation: earthOrientation)
		#expect(abs((fromTDB - fromTT).normalizedSigned().radians) <= 1e-12)
		#expect(try EarthRotation.greenwichMeanSiderealTime(at: ut1, context: context) == fromUT1)

		// GMST leads the ERA by the accumulated precession in right ascension, about 0.32° in late
		// 2024.
		let lead = (fromTT - EarthRotation.angle(at: ut1)).normalizedSigned()
		#expect(abs(lead.degrees - 0.317_6) <= 0.01)
	}

	@Test func range() throws {
		for days in stride(from: -400_000.0, through: 400_000, by: 12_345.678) {
			let ut1 = try Instant<UT1>(JulianDate.J2000.adding(days: days))
			let era = EarthRotation.angle(at: ut1).radians
			#expect(era >= 0 && era < 2 * .pi)
			let gmst = EarthRotation.greenwichMeanSiderealTime(ut1: ut1.julianDate, tt: ut1.julianDate).radians
			#expect(gmst >= 0 && gmst < 2 * .pi)
		}
	}

	@Test func errors() throws {
		let earthOrientation = EarthOrientation(ut1: UT1.Context(deltaT: DeltaTSourceList([])))
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try EarthRotation.greenwichMeanSiderealTime(at: Instant<TT>(.J2000), earthOrientation: earthOrientation)
		}
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try EarthRotation.greenwichMeanSiderealTime(at: Instant<UT1>(.J2000), earthOrientation: earthOrientation)
		}
	}
}
