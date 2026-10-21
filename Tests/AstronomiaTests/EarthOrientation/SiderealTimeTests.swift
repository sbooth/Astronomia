//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct SiderealTimeTests {
	static let uas = microarcsecondsPerRadian

	/// The difference of two angles in microarcseconds, across the turn.
	static func difference(_ a: Angle, _ b: Double) -> Double {
		abs((a.radians - b).remainder(dividingBy: twoPi)) * uas
	}

	@Test func matchesERFA() throws {
		// gst06a with UT1 = TT, eo06a, and ee06a, which agree as the nutation does
		for value in erfaIAU2006 {
			let tt = try Instant<TT>(JulianDate(julianDate: value.julianDate))
			let tolerance = IAU2006Tests.nutationTolerance(at: tt.julianDate.julianCenturiesSinceJ2000)
			let gast = EarthRotation.greenwichApparentSiderealTime(ut1: tt.julianDate, tt: tt, earthOrientation: .model)
			#expect(Self.difference(gast, value.siderealTime[2]) <= tolerance, "\(value.julianDate)")
			#expect(Self.difference(EarthRotation.equationOfTheOrigins(at: tt), value.siderealTime[3]) <= tolerance, "\(value.julianDate)")
			#expect(Self.difference(EarthRotation.equationOfTheEquinoxes(at: tt), value.siderealTime[1]) <= tolerance, "\(value.julianDate)")
		}
	}

	@Test func apparentLessMeanIsTheEquationOfTheEquinoxes() throws {
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_967.25))
		let gast = try EarthRotation.greenwichApparentSiderealTime(at: tt)
		let gmst = try EarthRotation.greenwichMeanSiderealTime(at: tt)
		let equation = EarthRotation.equationOfTheEquinoxes(at: tt)
		#expect(abs((gast - gmst).normalizedSigned().radians - equation.radians) * Self.uas <= 0.01)
		// Near 2026 it is about a second of time at most: Δψ cos ε_A, with |Δψ| below 20″.
		#expect(abs(equation.arcseconds) <= 18)
	}

	@Test func instantsAgree() throws {
		// GAST at a UT1 instant and at the same instant in TT agree.
		let ut1 = try Instant<UT1>(JulianDate(julianDate: 2_460_000.5))
		let tt = try ut1.converted(to: TT.self)
		let fromUT1 = try EarthRotation.greenwichApparentSiderealTime(at: ut1)
		let fromTT = try EarthRotation.greenwichApparentSiderealTime(at: tt)
		#expect(abs((fromUT1 - fromTT).normalizedSigned().radians) * Self.uas <= 1)
	}

	@Test func poleOffsetsMoveTheEquinox() throws {
		// With offsets the true equinox moves along the equator by about δΔψ cos ε_A, so GAST
		// and the equations of the origins and equinoxes change by about 0.7 mas.
		let offsets = CelestialPoleOffsets(dX: Angle(arcseconds: 0.3e-3), dY: Angle(arcseconds: -0.2e-3))
		let entries = (2_460_000 ... 2_460_002).map { EarthOrientationTable.Entry(utcDay: $0, ut1MinusUTC: -0.01, celestialPoleOffsets: offsets) }
		let observed = EarthOrientation(table: try #require(EarthOrientationTable(entries: entries)))
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_001))
		let shift = (EarthRotation.equationOfTheEquinoxes(at: tt, earthOrientation: observed) - EarthRotation.equationOfTheEquinoxes(at: tt)).radians
		let longitude = (IAU2006.nutation(at: tt, earthOrientation: observed).longitude - IAU2006.nutation(at: tt).longitude).radians
		#expect(abs(shift - longitude * Math.cos(IAU2006.meanObliquity(at: tt).radians)) <= 0.05 * abs(shift))
		#expect((600 ... 800).contains(abs(shift) * Self.uas))
		let origins = (EarthRotation.equationOfTheOrigins(at: tt, earthOrientation: observed) - EarthRotation.equationOfTheOrigins(at: tt)).radians
		#expect(abs(origins + shift) * Self.uas <= 0.001)
	}

	@Test func modelQuantitiesMatchERFA() throws {
		// nut06a, obl06, bpn2xy, and s06
		for value in erfaIAU2006 {
			let tt = try Instant<TT>(JulianDate(julianDate: value.julianDate))
			let tolerance = IAU2006Tests.nutationTolerance(at: tt.julianDate.julianCenturiesSinceJ2000)
			let nutation = IAU2006.nutation(at: tt)
			#expect(abs(nutation.longitude.radians - value.nutation[0]) * Self.uas <= tolerance, "\(value.julianDate)")
			#expect(abs(nutation.obliquity.radians - value.nutation[1]) * Self.uas <= 3, "\(value.julianDate)")
			#expect(abs(IAU2006.meanObliquity(at: tt).radians - value.angles[3]) * Self.uas <= 1e-4, "\(value.julianDate)")
			let pole = IAU2006.celestialIntermediatePole(at: tt)
			#expect(abs(pole.x.radians - value.cip[0]) * Self.uas <= tolerance, "\(value.julianDate)")
			#expect(abs(pole.y.radians - value.cip[1]) * Self.uas <= tolerance, "\(value.julianDate)")
			#expect(abs(IAU2006.cioLocator(at: tt).radians - value.cip[2]) * Self.uas <= 0.3, "\(value.julianDate)")
		}
	}

	@Test func anyTimescale() throws {
		// An instant in another timescale is converted to TT first.
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_000.5))
		let tdb = try tt.converted(to: TDB.self)
		let utc = try tt.converted(to: UTC.self)
		#expect(try IAU2006.nutation(at: tdb) == IAU2006.nutation(at: tt))
		#expect(try IAU2006.meanObliquity(at: tdb) == IAU2006.meanObliquity(at: tt))
		#expect(try IAU2006.celestialIntermediatePole(at: tdb) == IAU2006.celestialIntermediatePole(at: tt))
		#expect(try IAU2006.cioLocator(at: tdb) == IAU2006.cioLocator(at: tt))
		#expect(try EarthRotation.equationOfTheOrigins(at: tdb) == EarthRotation.equationOfTheOrigins(at: tt))
		#expect(try EarthRotation.equationOfTheEquinoxes(at: tdb) == EarthRotation.equationOfTheEquinoxes(at: tt))
		let gast = try EarthRotation.greenwichApparentSiderealTime(at: tt)
		#expect(abs((try EarthRotation.greenwichApparentSiderealTime(at: utc) - gast).normalizedSigned().radians) * Self.uas <= 1)
		// A UT1 instant with a UT1 context as its timescale context keeps its UT1.
		let ut1Context = UT1.Context(deltaT: DeltaTFunction.constant(69.2))
		let ut1 = try tt.converted(to: UT1.self, targetContext: ut1Context)
		let generic = try EarthRotation.greenwichApparentSiderealTime(at: ut1, context: ut1Context)
		let expected = EarthRotation.greenwichApparentSiderealTime(ut1: ut1.julianDate, tt: try ut1.converted(to: TT.self, sourceContext: ut1Context), earthOrientation: .model)
		#expect(generic == expected)
	}

	@Test func earthOrientationTakesUT1FromItsTable() throws {
		// The default source of UT1 follows the table where it covers the date: UT1 - UTC of
		// -0.25 s instead of the built-in data's value.
		let entries = (2_460_000 ... 2_460_002).map { EarthOrientationTable.Entry(utcDay: $0, ut1MinusUTC: -0.25) }
		let table = try #require(EarthOrientationTable(entries: entries))
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_001))
		let fromTable = try UT1.fromTT(tt.julianDate, context: EarthOrientation(table: table).ut1)
		let expected = try UT1.fromTT(tt.julianDate, context: UT1.Context(earthOrientation: table))
		#expect(fromTable == expected)
		#expect(try UT1.fromTT(tt.julianDate, context: EarthOrientation.model.ut1) != fromTable)
	}
}
