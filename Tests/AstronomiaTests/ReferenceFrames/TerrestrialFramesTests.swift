//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct TerrestrialFramesTests {
	static let uas = microarcsecondsPerRadian
	/// UT1 = TT - 69.184 s, as in the ERFA reference values
	static let ut1Context = UT1.Context(deltaT: DeltaTFunction.constant(69.184))
	/// The Earth's equatorial radius, in astronomical units
	static let earthRadius = 6_378.137 / Distance.kilometersPerAstronomicalUnit

	/// A table with constant polar motion of 0.12" and 0.34" from 2023-02-23 to 2025-10-23 UTC,
	/// and UT1 from a constant ΔT.
	static func observed() throws -> EarthOrientation {
		let motion = PolarMotion(x: Angle(arcseconds: 0.12), y: Angle(arcseconds: 0.34))
		let entries = [2_459_999, 2_461_000].map { EarthOrientationTable.Entry(utcDay: $0, ut1MinusUTC: 0, polarMotion: motion) }
		return EarthOrientation(table: EarthOrientationTable(entries: entries), ut1: ut1Context)
	}

	@Test func rotationsMatchERFA() throws {
		// era00 times c2i06a for the TIRS, pom00, and c2t06a for the ITRS, which differ from the
		// model here by the nutation series, as in IAU2006Tests
		for value in erfaTerrestrial {
			let tt = try Instant<TT>(JulianDate(julianDate: value.julianDate))
			let ut1 = try Instant<UT1>(tt.julianDate.adding(seconds: -69.184))
			let tolerance = IAU2006Tests.nutationTolerance(at: tt.julianDate.julianCenturiesSinceJ2000)
			let tirs = TIRS.rotationFromICRS(at: tt, ut1: ut1, earthOrientation: .model)
			#expect(FramesOfDateTests.difference(tirs, value.tirs) <= tolerance, "\(value.julianDate)")
			#expect(tirs.toEpoch == tt)
			let x = Angle(arcseconds: 0.12).radians
			let y = Angle(arcseconds: 0.34).radians
			let polarMotion = IAU2006.polarMotion(x: x, y: y, sPrime: IAU2006.tioLocator(at: tt.julianDate.julianCenturiesSinceJ2000))
			#expect(FramesOfDateTests.difference(polarMotion, value.polarMotion) <= 1e-4, "\(value.julianDate)")
			let itrs = polarMotion * IAU2006.terrestrialIntermediate(at: tt, ut1: ut1, earthOrientation: .model)
			#expect(FramesOfDateTests.difference(itrs, value.itrs) <= tolerance, "\(value.julianDate)")
		}
	}

	@Test func polarMotionComesFromTheTable() throws {
		// Within the table, the ITRS follows its polar motion, and UT1 its source of UT1.
		let observed = try Self.observed()
		for value in erfaTerrestrial where value.julianDate > 2_460_000 {
			let tt = try Instant<TT>(JulianDate(julianDate: value.julianDate))
			let tolerance = IAU2006Tests.nutationTolerance(at: tt.julianDate.julianCenturiesSinceJ2000)
			#expect(FramesOfDateTests.difference(try ITRS.rotationFromICRS(at: tt, earthOrientation: observed), value.itrs) <= tolerance)
		}
		// Without it, there is no polar motion: the ITRS is the TIRS turned by s', about 11 µas
		// in 2023.
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_000.5))
		let ut1 = try tt.converted(to: UT1.self)
		let sPrime = IAU2006.tioLocator(at: tt.julianDate.julianCenturiesSinceJ2000)
		let unlabeled: Rotation<ICRS, ICRS> = TIRS.rotationFromICRS(at: tt, ut1: ut1, earthOrientation: .model).relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: NoEpoch())
		let tirs = Rotation<ICRS, ICRS>.aboutZ(Angle(radians: sPrime)) * unlabeled
		let itrs = ITRS.rotationFromICRS(at: tt, ut1: ut1, earthOrientation: .model)
		let rows = [tirs.rows.0, tirs.rows.1, tirs.rows.2].flatMap { [$0.x, $0.y, $0.z] }
		#expect(FramesOfDateTests.difference(itrs, rows) <= 0.001)
		#expect(abs(sPrime) * Self.uas >= 10)
	}

	@Test func positionsRoundTrip() throws {
		let earthOrientation = EarthOrientation(ut1: Self.ut1Context)
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_967.25))
		let position = Position<ICRS>(x: .astronomicalUnits(0.3), y: .astronomicalUnits(-0.4), z: .astronomicalUnits(0.2))
		let itrs = try position.converted(to: ITRS.self, at: tt, earthOrientation: earthOrientation)
		expectClose(try itrs.converted(to: ICRS.self, at: tt, earthOrientation: earthOrientation).vector, position.vector, 3e-16)
		let tirs = try position.converted(to: TIRS.self, at: tt, earthOrientation: earthOrientation)
		#expect(tirs.epoch == tt)
		expectClose(try tirs.converted(to: ICRS.self, earthOrientation: earthOrientation).vector, position.vector, 3e-16)
		// Fixed frames other than the ICRS go through it.
		let ecliptic = position.converted(to: EclipticJ2000.self)
		expectClose(try ecliptic.converted(to: ITRS.self, at: tt, earthOrientation: earthOrientation).vector, itrs.vector, 3e-16)
		// Positions fixed to the Earth add, as in a fixed frame.
		let sum: Position<ITRS> = itrs + itrs
		expectClose(sum.vector, itrs.vector * 2, 0)
	}

	@Test func instantsInOtherTimescales() throws {
		// A UT1 instant keeps its UT1, and TT comes from the context given with it.
		let earthOrientation = EarthOrientation(ut1: Self.ut1Context)
		let ut1 = try Instant<UT1>(JulianDate(julianDate: 2_460_967.25))
		let tt = try ut1.converted(to: TT.self, sourceContext: Self.ut1Context)
		let position = Position<ICRS>(x: .astronomicalUnits(1), y: .astronomicalUnits(0), z: .astronomicalUnits(0))
		let expected = ICRS.rotation(to: ITRS.self, at: tt, ut1: ut1, earthOrientation: earthOrientation) * position
		#expect(try position.converted(to: ITRS.self, at: ut1, context: Self.ut1Context, earthOrientation: earthOrientation) == expected)
		// From TDB, both are converted.
		let tdb = try tt.converted(to: TDB.self)
		expectClose(try position.converted(to: ITRS.self, at: tdb, earthOrientation: earthOrientation).vector, expected.vector, 1e-14)
		#expect(try expected.converted(to: ICRS.self, at: ut1, context: Self.ut1Context, earthOrientation: earthOrientation).vector == (ITRS.rotation(at: tt, ut1: ut1, to: ICRS.self, earthOrientation: earthOrientation) * expected).vector)
	}

	@Test func statesIncludeTheEarthsRotation() throws {
		let earthOrientation = EarthOrientation(ut1: Self.ut1Context)
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_967.25))
		// A point on the equator, at rest on the Earth, moves at about 465 m/s in the ICRS.
		let site = Position<ITRS>(x: .astronomicalUnits(Self.earthRadius), y: .zero, z: .zero)
		let atRest = StateVector(position: site, velocity: .zero)
		let inertial = try atRest.converted(to: ICRS.self, at: tt, earthOrientation: earthOrientation)
		let speed = Velocity<ICRS>(inertial.velocity.vector, frameEpoch: NoEpoch()).kilometersPerSecond
		let kms = (speed * speed).sum().squareRoot()
		#expect(abs(kms - 0.465_1) <= 0.000_1)
		// And back at rest
		let back = try inertial.converted(to: ITRS.self, at: tt, earthOrientation: earthOrientation)
		expectClose(back.position.vector, site.vector, 1e-19)
		expectClose(back.velocity.vector, .zero, 1e-19)
		// Through the TIRS too
		let tirs = try inertial.converted(to: TIRS.self, at: tt, earthOrientation: earthOrientation)
		#expect(tirs.epoch == tt)
		expectClose(tirs.velocity.vector, .zero, 1e-14)
		expectClose(try tirs.converted(to: ICRS.self, earthOrientation: earthOrientation).velocity.vector, inertial.velocity.vector, 1e-19)
	}

	@Test func velocityIsTheDerivativeOfPosition() throws {
		// For a point at rest in the ICRS, the ITRS velocity is the derivative of its ITRS
		// position, to the frame's precession and nutation, which turn it about 1e-7 as fast
		// as the Earth's rotation.
		let earthOrientation = EarthOrientation(ut1: Self.ut1Context)
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_967.25))
		let position = Position<ICRS>(x: .astronomicalUnits(2e-4), y: .astronomicalUnits(-1e-4), z: .astronomicalUnits(5e-5))
		let state = try StateVector(position: position, velocity: .zero).converted(to: ITRS.self, at: tt, earthOrientation: earthOrientation)
		let h = 10.0 / 86_400
		let later = try position.converted(to: ITRS.self, at: Instant<TT>(tt.julianDate.adding(days: h)), earthOrientation: earthOrientation)
		let earlier = try position.converted(to: ITRS.self, at: Instant<TT>(tt.julianDate.adding(days: -h)), earthOrientation: earthOrientation)
		let derivative = (later.vector - earlier.vector) * (1 / (2 * h))
		#expect((derivative - state.velocity.vector).length <= 2e-7 * derivative.length)
	}

	@Test func excessLengthOfDaySlowsTheRotation() throws {
		// A day longer by 2 ms turns the Earth more slowly by 2 ms in 86,400 s.
		let entries = [2_460_000, 2_460_001].map { EarthOrientationTable.Entry(utcDay: $0, ut1MinusUTC: 0, excessLengthOfDay: 0.002) }
		let observed = EarthOrientation(table: EarthOrientationTable(entries: entries))
		let tt = try Instant<TT>(JulianDate(julianDate: 2_460_000))
		let nominal = TIRS.angularVelocity(at: tt, earthOrientation: .model).z
		#expect(abs(nominal - 2 * Double.pi * 1.002_737_811_911_354_48) <= 1e-15)
		#expect(abs(TIRS.angularVelocity(at: tt, earthOrientation: observed).z / nominal - (1 - 0.002 / 86_400)) <= 1e-15)
	}
}
