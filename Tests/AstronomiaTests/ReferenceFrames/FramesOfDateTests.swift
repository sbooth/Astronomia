//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct FramesOfDateTests {
	static let uas = microarcsecondsPerRadian

	/// The largest difference between a rotation's elements and nine values by rows, in µas.
	static func difference<A, B>(_ rotation: Rotation<A, B>, _ expected: [Double]) -> Double {
		let rows = [rotation.rows.0, rotation.rows.1, rotation.rows.2]
		var largest = 0.0
		for i in 0 ..< 3 {
			for j in 0 ..< 3 {
				largest = max(largest, abs(rows[i][j] - expected[3 * i + j]))
			}
		}
		return largest * uas
	}

	@Test func rotationsMatchERFA() throws {
		// bp06 and ecm06 evaluate the same precession, and pnm06a, c2i06a, and the true
		// ecliptic differ by the nutation series, as in IAU2006Tests.
		for value in erfaIAU2006 {
			let epoch = try Instant<TT>(JulianDate(julianDate: value.julianDate))
			let tolerance = IAU2006Tests.nutationTolerance(at: epoch.julianDate.julianCenturiesSinceJ2000)
			#expect(Self.difference(MeanEquatorOfDate.rotationFromICRS(at: epoch), value.frames[0]) <= 1e-4, "\(value.julianDate)")
			#expect(Self.difference(MeanEclipticOfDate.rotationFromICRS(at: epoch), value.frames[1]) <= 1e-4, "\(value.julianDate)")
			#expect(Self.difference(CIRS.rotationFromICRS(at: epoch), value.frames[2]) <= tolerance, "\(value.julianDate)")
			#expect(Self.difference(TrueEquatorOfDate.rotationFromICRS(at: epoch), value.matrix) <= tolerance, "\(value.julianDate)")
			#expect(Self.difference(TrueEclipticOfDate.rotationFromICRS(at: epoch), value.frames[3]) <= tolerance, "\(value.julianDate)")
		}
	}

	@Test func rotationsHaveTheirEpoch() throws {
		let epoch = try Instant<TT>(JulianDate(julianDate: 2_460_000.5))
		#expect(CIRS.rotationFromICRS(at: epoch).toEpoch == epoch)
		#expect(TrueEquatorOfDate.rotation(from: epoch, to: ICRS.self).fromEpoch == epoch)
		#expect(EclipticJ2000.rotation(to: MeanEclipticOfDate.self, at: epoch).toEpoch == epoch)
	}

	@Test func trueEquatorIsTheIntermediateSystemTurnedByTheEquationOfTheOrigins() throws {
		// With zero pole offsets the true equator is built as R3(EO) times the CIRS, rather than
		// as bias, precession, and nutation; the two agree to rounding.
		for t in [-10.0, -1, 0, 0.26, 1, 10] {
			let model = IAU2006.Orientation(at: t, poleOffsets: nil)
			let zero = IAU2006.Orientation(at: t, poleOffsets: (0, 0))
			let rows = [model.trueEquator.rows.0, model.trueEquator.rows.1, model.trueEquator.rows.2]
			#expect(Self.difference(zero.trueEquator, rows.flatMap { [$0.x, $0.y, $0.z] }) <= 1e-4, "\(t)")
		}
	}

	@Test func poleOffsetsMatchERFA() throws {
		// The change the offsets make to the CIRS agrees with c2ixys given X + dX and Y + dY.
		let dX = Angle(arcseconds: 0.3e-3).radians
		let dY = Angle(arcseconds: -0.2e-3).radians
		for value in erfaCIRSWithPoleOffsets {
			let t = try JulianDate(julianDate: value.julianDate).julianCenturiesSinceJ2000
			let model = try #require(erfaIAU2006.first { $0.julianDate == value.julianDate }).frames[2]
			let expected = zip(value.matrix, model).map { $0 - $1 }
			let with = IAU2006.Orientation(at: t, poleOffsets: (dX, dY)).intermediate
			let without = IAU2006.Orientation(at: t, poleOffsets: nil).intermediate
			let actual = [with.rows.0 - without.rows.0, with.rows.1 - without.rows.1, with.rows.2 - without.rows.2]
			for i in 0 ..< 3 {
				for j in 0 ..< 3 {
					#expect(abs(actual[i][j] - expected[3 * i + j]) * Self.uas <= 0.001, "\(value.julianDate) \(i) \(j)")
				}
			}
			// The pole moves by the offsets in the CIRS and the true equator alike.
			let corrected = IAU2006.Orientation(at: t, poleOffsets: (dX, dY))
			let modelPole = IAU2006.Orientation(at: t, poleOffsets: nil).trueEquator.storage.2
			#expect(abs(corrected.trueEquator.storage.2.x - modelPole.x - dX) * Self.uas <= 0.001)
			#expect(abs(corrected.trueEquator.storage.2.y - modelPole.y - dY) * Self.uas <= 0.001)
		}
	}

	@Test func poleOffsetsMoveTheTrueEquinox() throws {
		// The corrected nutation gives the corrected pole, and the true equator built from the
		// CIRS matches bias, precession, and the corrected nutation, origin and all. The
		// equinox moves along the equator by δΔψ cos ε_A to a few percent, near 0.7 mas for
		// dX = 0.3 mas.
		let dX = Angle(arcseconds: 0.3e-3).radians
		let dY = Angle(arcseconds: -0.2e-3).radians
		for t in [-10.0, -1, 0, 0.26, 1, 10] {
			let corrected = IAU2006.Orientation(at: t, poleOffsets: (dX, dY))
			let model = IAU2006.Orientation(at: t, poleOffsets: nil)
			let expected = IAU2006.biasPrecessionNutation(angles: corrected.angles, nutation: corrected.nutation)
			let rows = [expected.rows.0, expected.rows.1, expected.rows.2]
			#expect(Self.difference(corrected.trueEquator, rows.flatMap { [$0.x, $0.y, $0.z] }) <= 0.001, "\(t)")
			let shift = corrected.equationOfOrigins - model.equationOfOrigins
			let longitude = corrected.nutation.longitude - model.nutation.longitude
			#expect(abs(shift + longitude * Math.cos(corrected.angles.epsilon)) <= 0.05 * abs(shift), "\(t)")
			#expect((500 ... 800).contains(abs(shift) * Self.uas), "\(t)")
		}
	}

	@Test func contextAppliesTheTablesOffsets() throws {
		// A table with constant offsets of 0.3 and -0.2 mas from 2023-02-25 to 2023-02-27 UTC
		let offsets = CelestialPoleOffsets(dX: Angle(arcseconds: 0.3e-3), dY: Angle(arcseconds: -0.2e-3))
		let entries = (2_460_000 ... 2_460_002).map { EarthOrientationTable.Entry(utcDay: $0, ut1MinusUTC: -0.01, celestialPoleOffsets: offsets) }
		let table = try #require(EarthOrientationTable(entries: entries))
		let context = EarthOrientation(table: table)
		let covered = try Instant<TT>(JulianDate(julianDate: 2_460_001))
		let t = covered.julianDate.julianCenturiesSinceJ2000
		let expected = IAU2006.Orientation(at: t, poleOffsets: (offsets.dX.radians, offsets.dY.radians)).intermediate
		let actual = CIRS.rotationFromICRS(at: covered, earthOrientation: context)
		#expect(Self.difference(actual, [expected.rows.0, expected.rows.1, expected.rows.2].flatMap { [$0.x, $0.y, $0.z] }) <= 1e-9)
		// Outside the table, the model alone
		let outside = try Instant<TT>(JulianDate(julianDate: 2_460_100.5))
		#expect(CIRS.rotationFromICRS(at: outside, earthOrientation: context) == CIRS.rotationFromICRS(at: outside))
		// The mean frames don't use it.
		#expect(MeanEquatorOfDate.rotationFromICRS(at: covered, earthOrientation: context) == MeanEquatorOfDate.rotationFromICRS(at: covered))
	}

	@Test func meanEclipticAtJ2000IsTheEclipticOfJ2000() {
		let rotation = MeanEclipticOfDate.rotationFromICRS(at: Instant<TT>(.j2000))
		let rows = [EclipticJ2000.rotationFromICRS.rows.0, EclipticJ2000.rotationFromICRS.rows.1, EclipticJ2000.rotationFromICRS.rows.2]
		#expect(Self.difference(rotation, rows.flatMap { [$0.x, $0.y, $0.z] }) <= 1e-4)
	}

	@Test func trueEclipticLongitudeIsMeanPlusNutation() throws {
		// Nutation turns the equinox along the ecliptic of date by Δψ and leaves latitude alone.
		let epoch = try Instant<TT>(JulianDate(julianDate: 2_460_000.5))
		let star = Position<ICRS>(SphericalPosition(rightAscension: Angle(degrees: 101.287), declination: Angle(degrees: -16.716), distance: Distance(astronomicalUnits: 1)))
		let mean = star.converted(to: MeanEclipticOfDate.self, at: epoch).spherical
		let apparent = star.converted(to: TrueEclipticOfDate.self, at: epoch).spherical
		let t = epoch.julianDate.julianCenturiesSinceJ2000
		let nutation = IAU2006.nutation(at: t, arguments: IAU2006.FundamentalArguments(at: t))
		#expect(abs((apparent.longitude - mean.longitude).radians - nutation.longitude) * Self.uas <= 0.01)
		#expect(abs((apparent.latitude - mean.latitude).radians) * Self.uas <= 0.01)
	}

	@Test func conversions() throws {
		let epoch = try Instant<TT>(JulianDate(julianDate: 2_460_000.5))
		let later = try Instant<TT>(JulianDate(julianDate: 2_469_807.5))
		let position = Position<ICRS>(x: .astronomicalUnits(1), y: .astronomicalUnits(-2), z: .astronomicalUnits(0.5))
		// To a frame of date and back
		let tod = position.converted(to: TrueEquatorOfDate.self, at: epoch)
		#expect(tod.epoch == epoch)
		expectClose(tod.vector, TrueEquatorOfDate.rotationFromICRS(at: epoch).apply(to: position.vector), 0)
		expectClose(tod.converted(to: ICRS.self).vector, position.vector, 1e-15)
		// From one frame of date and epoch to another
		let cirs = tod.converted(to: CIRS.self, at: later)
		#expect(cirs.epoch == later)
		expectClose(cirs.vector, position.converted(to: CIRS.self, at: later).vector, 1e-15)
		// Between fixed frames through a frame of date
		expectClose(tod.converted(to: EclipticJ2000.self).vector, position.converted(to: EclipticJ2000.self).vector, 1e-15)
		// An epoch in another timescale is converted to TT.
		let tdb = try epoch.converted(to: TDB.self)
		expectClose(try position.converted(to: CIRS.self, at: tdb).vector, position.converted(to: CIRS.self, at: epoch).vector, 1e-15)
		#expect(try position.converted(to: CIRS.self, at: tdb).epoch == epoch)
		// Velocities and states rotate with the same rotation.
		let velocity = Velocity<ICRS>(astronomicalUnitsPerDay: SIMD3(0.01, 0.02, -0.003))
		let state = StateVector(position: position, velocity: velocity).converted(to: MeanEclipticOfDate.self, at: epoch)
		#expect(state.epoch == epoch)
		expectClose(state.position.vector, position.converted(to: MeanEclipticOfDate.self, at: epoch).vector, 0)
		expectClose(state.velocity.vector, velocity.converted(to: MeanEclipticOfDate.self, at: epoch).vector, 0)
		expectClose(state.converted(to: ICRS.self).velocity.vector, velocity.vector, 1e-17)
		expectClose(try state.converted(to: TrueEquatorOfDate.self, at: tdb).position.vector, tod.vector, 1e-15)
	}
}
