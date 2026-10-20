//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// A ΔT source that never has ΔT.
private struct NoDeltaT: DeltaTSource {
	var coverage: ClosedRange<JulianDate> {
		let j2000 = JulianDate(uncheckedJulianDayNumber: 2_451_545, fractionFromNoon: 0)
		return j2000 ... j2000
	}

	func deltaT(at tt: JulianDate) -> Double? {
		nil
	}
}

/// An instant in TDB within the coverage of the built-in ephemerides.
private let tdb = Instant<TDB>(JulianDate(uncheckedJulianDayNumber: 2_460_000, fractionFromNoon: 0.25))

private func vector(_ values: [Double]) -> Vector3 {
	Vector3(values[0], values[1], values[2])
}

/// The geocentric state of a body from any ephemeris that gives the Earth, in the ICRS, as
/// generic code finds it.
private func geocentricState<E: GeocentricEphemeris>(of body: E.Body, from ephemeris: E, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
	try ephemeris.state(of: body, relativeTo: E.earth, at: tdb).converted(to: ICRS.self)
}

@Suite struct VSOP2013SolutionTests {
	let solution = VSOP2013.Solution()

	@Test func nativeFrameAndOrigin() throws {
		// States are heliocentric in the solution's ecliptic, without rotation.
		let mars = try solution.state(of: .mars, at: tdb)
		let ecliptic = try #require(VSOP2013.heliocentricState(of: .mars, at: tdb.julianDate))
		#expect(mars.position.vector == ecliptic.position && mars.velocity.vector == ecliptic.velocity)
		#expect(VSOP2013.Solution.defaultOrigin == .sun)
	}

	@Test func originsCompose() throws {
		let venus = try solution.state(of: .venus, relativeTo: .saturnBarycenter, at: tdb)
		let fromSun = try solution.state(of: .venus, at: tdb) - solution.state(of: .saturnBarycenter, at: tdb)
		#expect(venus == fromSun)
		#expect(try solution.state(of: .sun, relativeTo: .venus, at: tdb) == -solution.state(of: .venus, at: tdb))
		#expect(try solution.state(of: .mars, relativeTo: .mars, at: tdb) == .zero)
	}

	@Test func barycenter() throws {
		// The masses weighted by their barycentric positions sum to zero.
		let sun = try solution.state(of: .sun, relativeTo: .solarSystemBarycenter, at: tdb)
		var moment = sun.position.vector * VSOP2013.sunGravitationalParameter
		for body in VSOP2013.Body.allCases {
			guard let series = body.series else { continue }
			let helio = try #require(VSOP2013.heliocentricState(of: body, at: tdb.julianDate))
			moment = moment + (helio.position + sun.position.vector) * series.bodyGravitationalParameter
		}
		#expect(moment.length <= 1e-19)
		// The Sun is within about two solar radii of the barycenter.
		#expect(sun.position.distance.kilometers < 1.6e6)
	}

	@Test func coverage() throws {
		#expect(solution.coverage.lowerBound.julianDate.daysSinceJ2000 == -365_250)
		#expect(solution.coverage.upperBound.julianDate.daysSinceJ2000 == 365_250)
		let early = try solution.coverage.lowerBound.julianDate.adding(seconds: -1)
		#expect(throws: EphemerisError.outsideCoverage) {
			try solution.state(of: .mars, at: Instant<TDB>(early))
		}
	}
}

@Suite struct ELPMPP02EphemerisTests {
	@Test func nativeFrameAndOrigin() throws {
		let solution = ELPMPP02.de405
		let moon = try solution.state(of: .moon, at: tdb)
		let ecliptic = try #require(ELPMPP02.eclipticState(at: tdb.julianDate, series: ELPMPP02.DE405.series))
		#expect(moon.position.vector == ecliptic.position && moon.velocity.vector == ecliptic.velocity)
		#expect(try solution.state(of: .earth, relativeTo: .moon, at: tdb) == -moon)
		#expect(try solution.state(of: .moon, relativeTo: .moon, at: tdb) == .zero)
		#expect(ELPMPP02.DE405.defaultOrigin == .earth && ELPMPP02.LaserRanging.defaultOrigin == .earth)
	}

	@Test func fits() throws {
		// The fit chooses the constants and the frame.
		let de405 = ELPMPP02.de405
		let laserRanging = ELPMPP02.laserRanging
		let a: StateVector<ELPMPP02.DE405.Ecliptic> = try de405.state(of: .moon, at: tdb)
		let b: StateVector<ELPMPP02.LaserRanging.Ecliptic> = try laserRanging.state(of: .moon, at: tdb)
		let ecliptic = try #require(ELPMPP02.eclipticState(at: tdb.julianDate, series: ELPMPP02.LaserRanging.series))
		#expect(b.position.vector == ecliptic.position)
		// The fits differ by tens of milliarcseconds in the ICRS.
		let separation = a.position.converted(to: ICRS.self).angularSeparation(from: b.position.converted(to: ICRS.self))
		#expect(separation.milliarcseconds > 1 && separation.milliarcseconds < 100)
	}

	@Test func coverage() throws {
		let solution = ELPMPP02.de405
		let late = try solution.coverage.upperBound.julianDate.adding(seconds: 1)
		#expect(throws: EphemerisError.outsideCoverage) {
			try solution.state(of: .moon, at: Instant<TDB>(late))
		}
		#expect(throws: EphemerisError.outsideCoverage) {
			try solution.state(of: .moon, relativeTo: .moon, at: Instant<TDB>(late))
		}
	}
}

@Suite struct SolarSystemEphemerisTests {
	let ephemeris = SolarSystemEphemeris()

	@Test func defaults() throws {
		#expect(SolarSystemEphemeris.defaultOrigin == .solarSystemBarycenter)
		#expect(SolarSystemEphemeris.earth == .earth && SolarSystemEphemeris.sun == .sun)
		#expect(SolarSystemEphemeris.solarSystemBarycenter == .solarSystemBarycenter)
		// The default lunar fit is DE405.
		#expect(ephemeris.lunarFit == .de405)
		#expect(ephemeris == SolarSystemEphemeris(lunarFit: .de405))
		#expect(ephemeris != SolarSystemEphemeris(lunarFit: .laserRanging))
		let moon = try #require(ephemeris.geocentricMoon(at: tdb.julianDate))
		let de405 = try #require(ELPMPP02.de405.icrsState(at: tdb.julianDate))
		#expect(moon.position == de405.position && moon.velocity == de405.velocity)
		let laserRanging = try #require(SolarSystemEphemeris(lunarFit: .laserRanging).geocentricMoon(at: tdb.julianDate))
		let expected = try #require(ELPMPP02.laserRanging.icrsState(at: tdb.julianDate))
		#expect(laserRanging.position == expected.position && laserRanging.velocity == expected.velocity)
	}

	@Test func coverageIsThatOfBothSolutions() {
		// Both solutions cover the same span, so the ephemeris covers all of it with either fit.
		for fit in SolarSystemEphemeris.LunarFit.allCases {
			let coverage = SolarSystemEphemeris(lunarFit: fit).coverage
			#expect(coverage == VSOP2013.solution.coverage)
			#expect(coverage == ELPMPP02.de405.coverage && coverage == ELPMPP02.laserRanging.coverage)
		}
	}

	@Test func moonIsELPMPP02() throws {
		let moon = try ephemeris.state(of: .moon, relativeTo: .earth, at: tdb)
		let elp = try ELPMPP02.de405.state(of: .moon, at: tdb).converted(to: ICRS.self)
		#expect((moon.position.vector - elp.position.vector).length <= 1e-15)
		#expect((moon.velocity.vector - elp.velocity.vector).length <= 1e-17)
		let laserRanging = SolarSystemEphemeris(lunarFit: .laserRanging)
		let other = try laserRanging.state(of: .moon, relativeTo: .earth, at: tdb)
		let elpOther = try ELPMPP02.laserRanging.state(of: .moon, at: tdb).converted(to: ICRS.self)
		#expect((other.position.vector - elpOther.position.vector).length <= 1e-15)
	}

	@Test func planetsAreVSOP2013() throws {
		let venus = try ephemeris.state(of: .venus, relativeTo: .saturnBarycenter, at: tdb)
		let vsop = try VSOP2013.Solution().state(of: .venus, relativeTo: .saturnBarycenter, at: tdb).converted(to: ICRS.self)
		#expect((venus.position.vector - vsop.position.vector).length <= 1e-15)
		let sun = try ephemeris.state(of: .sun, at: tdb)
		let vsopSun = try VSOP2013.Solution().state(of: .sun, relativeTo: .solarSystemBarycenter, at: tdb).converted(to: ICRS.self)
		#expect((sun.position.vector - vsopSun.position.vector).length <= 1e-18)
	}

	@Test func combinesTheSolutions() throws {
		// The combination as documented, from the two solutions
		let μ = SolarSystemEphemeris.earthMoonMassRatio
		let barycenter = try VSOP2013.Solution().state(of: .earthMoonBarycenter, at: tdb).converted(to: ICRS.self)
		let geocentricMoon = try ELPMPP02.de405.state(of: .moon, at: tdb).converted(to: ICRS.self)
		let earth = barycenter - geocentricMoon * (1 / (1 + μ))
		let moon = barycenter + geocentricMoon * (μ / (1 + μ))
		let expectedEarth = try ephemeris.state(of: .earth, relativeTo: .sun, at: tdb)
		let expectedMoon = try ephemeris.state(of: .moon, relativeTo: .sun, at: tdb)
		#expect((earth.position.vector - expectedEarth.position.vector).length <= 1e-15)
		#expect((moon.position.vector - expectedMoon.position.vector).length <= 1e-15)
		#expect((earth.velocity.vector - expectedEarth.velocity.vector).length <= 1e-17)
	}

	@Test func earthAndMoonBalanceAtTheirBarycenter() throws {
		let earth = try ephemeris.state(of: .earth, relativeTo: .earthMoonBarycenter, at: tdb)
		let moon = try ephemeris.state(of: .moon, relativeTo: .earthMoonBarycenter, at: tdb)
		let ratio = SolarSystemEphemeris.earthMoonMassRatio
		#expect((earth.position.vector + moon.position.vector / ratio).length <= 5e-16)
		#expect((earth.velocity.vector + moon.velocity.vector / ratio).length <= 2e-17)
		// The Earth is about 4,670 km from the barycenter.
		#expect(abs(earth.position.distance.kilometers - 4_670) <= 60)
	}

	@Test func originsCompose() throws {
		let marsFromEarth = try ephemeris.state(of: .mars, relativeTo: .earth, at: tdb)
		let earthFromSun = try ephemeris.state(of: .earth, relativeTo: .sun, at: tdb)
		let marsFromSun = try ephemeris.state(of: .mars, relativeTo: .sun, at: tdb)
		#expect(((marsFromEarth + earthFromSun).position.vector - marsFromSun.position.vector).length <= 1e-15)
		#expect(try ephemeris.state(of: .earth, relativeTo: .mars, at: tdb) == -marsFromEarth)
		#expect(try ephemeris.state(of: .venus, relativeTo: .venus, at: tdb) == .zero)
	}

	@Test func agreesWithDE421() throws {
		// DE421 and INPOP10a, to which VSOP2013 is fitted, differ most for the outer planets,
		// whose orbits the observations constrain least. The limits are the largest
		// differences from 1950 to 2050, rounded up.
		let bodies: [Int: (body: SolarSystemEphemeris.Body, limit: Double)] = [
			10: (.sun, 2), 199: (.mercury, 5), 299: (.venus, 2.5), 3: (.earthMoonBarycenter, 15),
			301: (.moon, 15), 499: (.mars, 3.5), 5: (.jupiterBarycenter, 35), 6: (.saturnBarycenter, 1),
			7: (.uranusBarycenter, 400), 8: (.neptuneBarycenter, 200), 9: (.plutoBarycenter, 3000),
		]
		let au = Distance.kilometersPerAstronomicalUnit
		for jd in Set(de421States.map(\.julianDate)) {
			let tdb = try Instant<TDB>(JulianDate(julianDate: jd))
			let rows = de421States.filter { $0.julianDate == jd }
			let earth = try #require(rows.first { $0.naifID == 399 })
			for row in rows where row.naifID != 399 {
				let (body, limit) = try #require(bodies[row.naifID])
				let geocentric = try geocentricState(of: body, from: ephemeris, at: tdb).position.vector * au
				let expected = vector(row.position) - vector(earth.position)
				let angle = Angle(radians: geocentric.cross(expected).length / expected.dot(expected))
				#expect(angle.milliarcseconds <= limit, "\(body) \(jd)")
			}
			// The barycentric Earth, for aberration and parallax
			let barycentric = try ephemeris.state(of: .earth, at: tdb)
			#expect((barycentric.position.vector * au - vector(earth.position)).length <= 2, "\(jd)")
			let speed = (barycentric.velocity.vector * au - vector(earth.velocity)).length * 1000 / secondsPerDay
			#expect(speed <= 0.001, "\(jd)")
		}
	}

	@Test func existential() throws {
		let any: any Ephemeris<SolarSystemEphemeris.Body, ICRS> = ephemeris
		#expect(try any.state(of: .moon, relativeTo: .earth, at: tdb) == ephemeris.state(of: .moon, relativeTo: .earth, at: tdb))
	}

	@Test func anyTimescale() throws {
		let tt = try tdb.converted(to: TT.self)
		let fromTT = try ephemeris.state(of: .venus, relativeTo: .earth, at: tt)
		let fromTDB = try ephemeris.state(of: .venus, relativeTo: .earth, at: tdb)
		#expect((fromTT.position.vector - fromTDB.position.vector).length <= 1e-15)
		let ut1 = Instant<UT1>(tdb.julianDate)
		#expect(throws: EphemerisError.timescaleConversion(.deltaTUnavailable)) {
			try ephemeris.state(of: .mars, at: ut1, context: UT1.Context(deltaT: NoDeltaT()))
		}
	}

	@Test func coverage() throws {
		let coverage = ephemeris.coverage
		#expect(coverage.lowerBound.julianDate.daysSinceJ2000 == -365_250)
		#expect(coverage.upperBound.julianDate.daysSinceJ2000 == 365_250)
		for body in [SolarSystemEphemeris.Body.moon, .earth, .solarSystemBarycenter] {
			_ = try ephemeris.state(of: body, relativeTo: .sun, at: coverage.lowerBound)
			_ = try ephemeris.state(of: body, relativeTo: .sun, at: coverage.upperBound)
		}
		let early = try coverage.lowerBound.julianDate.adding(seconds: -1)
		#expect(throws: EphemerisError.outsideCoverage) {
			try ephemeris.state(of: .moon, at: Instant<TDB>(early))
		}
	}
}
