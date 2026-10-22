//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct PlaceTests {
	static let uas = microarcsecondsPerRadian
	static let sunGravitationalParameter = VSOP2013.sunGravitationalParameter

	static func vector(_ values: [Double]) -> Vector3 {
		Vector3(values[0], values[1], values[2])
	}

	static func unit(_ v: Vector3) -> Vector3 {
		v / v.length
	}

	@Test func aberrationMatchesERFA() {
		for value in erfaAberration {
			let aberrated = Astrometry.aberrated(Self.vector(value.direction), velocity: Self.vector(value.velocity), sunDistance: value.sunDistance, sunGravitationalParameter: Self.sunGravitationalParameter)
			#expect((aberrated - Self.vector(value.aberrated)).length * Self.uas <= 0.001)
		}
	}

	@Test func deflectionMatchesERFA() {
		for value in erfaDeflection {
			let deflected = Astrometry.deflected(Self.vector(value.p), q: Self.vector(value.q), e: Self.vector(value.e), distance: value.distance, gravitationalParameter: value.mass * Self.sunGravitationalParameter, limit: 1e-9)
			#expect((deflected - Self.vector(value.deflected)).length * Self.uas <= 0.001)
		}
	}

	@Test func shapiroDelay() {
		// For light from Mercury at superior conjunction grazing the Sun's limb, at its closest
		// approach d, r_E + r_M - R is about (d² / 2)(1 / r_E + 1 / r_M), and the delay about
		// 110 µs, half the radar round trip.
		let gm = Self.sunGravitationalParameter
		let c = speedOfLightAstronomicalUnitsPerDay
		let rE = 1.0
		let rM = 0.39
		let d = Distance.kilometers(695_700).astronomicalUnits
		let shortfall = d * d / 2 * (1 / rE + 1 / rM)
		let delay = Astrometry.shapiroDelay(observerDistance: rE, targetDistance: rM, separation: rE + rM - shortfall, gravitationalParameter: gm) * secondsPerDay
		let expected = 2 * gm / (c * c * c) * Math.log((2 * (rE + rM) - shortfall) / shortfall) * secondsPerDay
		#expect(abs(delay - expected) <= 1e-12)
		#expect((100e-6 ... 120e-6).contains(delay), "\(delay)")
		// Without a body, or for a target at the body, there is none.
		#expect(Astrometry.shapiroDelay(observerDistance: rE, targetDistance: rM, separation: 1, gravitationalParameter: 0) == 0)
		#expect(Astrometry.shapiroDelay(observerDistance: rE, targetDistance: 0, separation: rE, gravitationalParameter: gm) == 0)
	}

	@Test func placesMatchSkyfield() throws {
		// Skyfield and DE421 against VSOP2013 and ELP/MPP02. The astrometric directions differ
		// by the ephemerides: a few mas for the inner planets and the Moon, tens of mas for
		// Jupiter, and up to 2.6" for Pluto. The corrections from astrometric to apparent, for
		// deflection and aberration, agree to 1.5 µas plus about 1e-4 of the difference in
		// direction, the size of aberration. Skyfield has no Shapiro delay, of up to 0.2 ms.
		let ephemerisTolerance: [SolarSystemEphemeris.Body: Double] = [
			.sun: 3, .moon: 12, .mercury: 6, .venus: 3, .mars: 4, .jupiterBarycenter: 35, .saturnBarycenter: 1,
			.uranusBarycenter: 450, .neptuneBarycenter: 250, .plutoBarycenter: 3_000,
		]
		let mas = Self.uas / 1000
		for value in skyfieldPlaces {
			let tdb = try Instant<TDB>(JulianDate(julianDate: value.julianDate))
			let astrometric = try Observer.geocenter.astrometricPlace(of: value.body, at: tdb)
			let apparent = try Observer.geocenter.apparentPlace(of: value.body, at: tdb)
			let referenceAstrometric = Self.vector(value.astrometric)
			let direction = (Self.unit(astrometric.position.vector) - Self.unit(referenceAstrometric)).length
			let tolerance = try #require(ephemerisTolerance[value.body])
			#expect(direction * mas <= tolerance, "\(value.body) \(value.julianDate)")
			let corrections = Self.unit(apparent.position.vector) - Self.unit(astrometric.position.vector)
			let referenceCorrections = Self.unit(Self.vector(value.apparent)) - Self.unit(referenceAstrometric)
			#expect((corrections - referenceCorrections).length * Self.uas <= 1.5 + 1e-4 * direction * Self.uas, "\(value.body) \(value.julianDate)")
			// The light time is the distance over c plus the Shapiro delay.
			let distance = (astrometric.position.vector.length - referenceAstrometric.length) / speedOfLightAstronomicalUnitsPerDay
			#expect(abs(astrometric.lightTime.inDays - value.lightTime - distance) * secondsPerDay <= 2e-4, "\(value.body) \(value.julianDate)")
			#expect(apparent.lightTime == astrometric.lightTime && apparent.instant == astrometric.instant)
			#expect(abs(apparent.position.vector.length - astrometric.position.vector.length) <= 1e-15 * astrometric.position.vector.length)
		}
	}

	@Test func lightTimeIsTheDistanceOverC() throws {
		// The light time solves τ = |r_T(t - τ) - r_O(t)| / c + Δt_S.
		let tdb = try Instant<TDB>(JulianDate(julianDate: 2_460_967.25))
		let positions = try Astrometry.Positions(ephemeris: SolarSystemEphemeris(), at: tdb)
		let earth = try positions.state(of: .earth)
		let geometry = try Astrometry.geometry(of: .jupiterBarycenter, observer: earth, positions: positions)
		let target = try positions.state(of: .jupiterBarycenter, daysEarlier: geometry.lightTime).position
		let sun = positions.sun.position
		let separation = (target - earth.position).length
		let delay = Astrometry.shapiroDelay(observerDistance: (earth.position - sun).length, targetDistance: (target - sun).length, separation: separation, gravitationalParameter: Self.sunGravitationalParameter)
		#expect(abs(geometry.lightTime - separation / speedOfLightAstronomicalUnitsPerDay - delay) * secondsPerDay <= 1e-9)
		#expect(delay > 0)
	}

	@Test func placesConvertAtTheirInstant() throws {
		let instant = try Instant<UTC>(JulianDate(julianDate: 2_460_967.25))
		let place = try Observer.geocenter.apparentPlace(of: .mars, at: instant)
		let tt = try instant.converted(to: TT.self)
		#expect(place.instant == tt)
		let ofDate = place.converted(to: TrueEquatorOfDate.self)
		#expect(ofDate.position == place.position.converted(to: TrueEquatorOfDate.self, at: tt))
		#expect(ofDate.position.epoch == tt && ofDate.instant == tt && ofDate.lightTime == place.lightTime)
		let cirs = ofDate.converted(to: CIRS.self)
		expectClose(cirs.position.vector, place.position.converted(to: CIRS.self, at: tt).vector, 1e-15)
		expectClose(ofDate.converted(to: ICRS.self).position.vector, place.position.vector, 1e-15)
		expectClose(place.converted(to: EclipticJ2000.self).position.vector, place.position.converted(to: EclipticJ2000.self).vector, 0)
		let astrometric = try Observer.geocenter.astrometricPlace(of: .mars, at: instant)
		#expect(astrometric.converted(to: EclipticJ2000.self).position == astrometric.position.converted(to: EclipticJ2000.self))
	}

	@Test func ephemerisAndObserver() throws {
		let tdb = try Instant<TDB>(JulianDate(julianDate: 2_460_967.25))
		// The built-in ephemeris by default, and the lunar fit chosen otherwise
		let built = try Observer.geocenter.apparentPlace(of: .moon, at: tdb)
		#expect(try Observer.geocenter.apparentPlace(of: .moon, at: tdb, ephemeris: SolarSystemEphemeris()) == built)
		let laserRanging = try Observer.geocenter.apparentPlace(of: .moon, at: tdb, ephemeris: SolarSystemEphemeris(lunarFit: .laserRanging))
		#expect(laserRanging != built)
		// The observer's own body is at the origin.
		let earth = try Observer.geocenter.apparentPlace(of: .earth, at: tdb)
		#expect(earth.position == .origin && earth.lightTime.inDays == 0)
		#expect(try Observer.geocenter.astrometricPlace(of: .earth, at: tdb).position == .origin)
		// Outside the ephemeris
		let early = try Instant<TDB>(JulianDate(julianDate: 2_000_000.5))
		#expect(throws: EphemerisError.outsideCoverage) { try Observer.geocenter.apparentPlace(of: .mars, at: early) }
	}

	@Test func lightDeflectingBodiesAreValidated() throws {
		let body = try LightDeflectingBody(body: 1, gravitationalParameter: 2.8e-4, radius: .kilometers(1_000))
		#expect(body.gravitationalParameter == 2.8e-4 && body.radius == .kilometers(1_000))
		#expect(try LightDeflectingBody(body: 1, gravitationalParameter: 0, radius: .meters(1)).gravitationalParameter == 0)
		for gravitationalParameter in [-1e-10, .nan, .infinity, -.infinity] {
			#expect(throws: LightDeflectingBodyError.invalidGravitationalParameter) {
				try LightDeflectingBody(body: 1, gravitationalParameter: gravitationalParameter, radius: .meters(1))
			}
		}
		// A body without a radius would deflect light passing through its center infinitely.
		for radius in [0, -0.0, -1e-10, .nan, .infinity, -.infinity] {
			#expect(throws: LightDeflectingBodyError.invalidRadius) {
				try LightDeflectingBody(body: 1, gravitationalParameter: 0, radius: .astronomicalUnits(radius))
			}
		}
		// The built-in bodies are valid.
		for deflector in SolarSystemEphemeris.lightDeflectingBodies {
			let checked = try LightDeflectingBody(body: deflector.body, gravitationalParameter: deflector.gravitationalParameter, radius: deflector.radius)
			#expect(checked == deflector && deflector.gravitationalParameter > 0)
		}
	}

	@Test func lightTimeEvaluatesTheTargetTwice() throws {
		let tdb = try Instant<TDB>(JulianDate(julianDate: 2_461_334.5))
		for (body, expected) in [(SolarSystemEphemeris.Body.moon, 2), (.mercury, 2), (.sun, 2), (.plutoBarycenter, 2), (.earth, 1)] {
			let ephemeris = AlteredEphemeris(altered: .solarSystemBarycenter)
			let positions = try Astrometry.Positions(ephemeris: ephemeris, at: tdb)
			let earth = try positions.state(of: .earth)
			let before = ephemeris.evaluations.counts[body] ?? 0
			let geometry = try Astrometry.geometry(of: body, observer: earth, positions: positions)
			#expect(ephemeris.evaluations.counts[body, default: 0] - before == expected, "\(body)")
			// The solution agrees with the target evaluated at its light time.
			let evaluated = try positions.state(of: body, daysEarlier: geometry.lightTime).position
			let direction = geometry.target - earth.position
			let reference = evaluated - earth.position
			if reference.length > 0 {
				#expect(Self.unit(direction).cross(Self.unit(reference)).length * Self.uas <= 0.05, "\(body)")
				#expect(abs(direction.length - reference.length) * kilometersPerAstronomicalUnit <= 1e-4, "\(body)")
			}
		}
	}

	/// Returns Mercury's direction from the Earth, its deflected direction, and the Sun's
	/// direction at an instant.
	static func mercuryNearTheSun(at julianDate: Double) throws -> (direction: Vector3, deflected: Vector3, sun: Vector3) {
		let tdb = try Instant<TDB>(JulianDate(julianDate: julianDate))
		let observation = try Observer.geocenter.observation(at: tdb)
		let earth = observation.observerVectors
		let geometry = try Astrometry.geometry(of: .mercury, observer: earth, positions: observation.positions)
		let direction = Self.unit(geometry.target - earth.position)
		let deflected = Astrometry.deflected(direction, geometry: geometry, deflectors: observation.deflectors, excluding: .mercury)
		return (direction, deflected, Self.unit(observation.positions.sun.position - earth.position))
	}

	@Test func deflectionNearTheSun() throws {
		// A day before Mercury's superior conjunction of 2026-05-14, its light passes about 1°
		// from the Sun and is deflected away from it by a few tenths of an arcsecond.
		let before = try Self.mercuryNearTheSun(at: 2_461_174)
		let elongation = Angle.atan2(y: before.direction.cross(before.sun).length, x: before.direction.dot(before.sun))
		let deflectedElongation = Angle.atan2(y: before.deflected.cross(before.sun).length, x: before.deflected.dot(before.sun))
		let deflection = (deflectedElongation - elongation).arcseconds
		#expect((0.5 ... 2).contains(elongation.degrees), "\(elongation.degrees)°")
		#expect((0.05 ... 1).contains(deflection), "\(deflection)\" at \(elongation.degrees)°")
		// At conjunction, 0.18° from the Sun's center, Mercury is behind the disk, and the Sun
		// deflects nothing; Jupiter and Saturn deflect less than 0.1 µas.
		let behind = try Self.mercuryNearTheSun(at: 2_461_175)
		#expect(Angle.atan2(y: behind.direction.cross(behind.sun).length, x: behind.direction.dot(behind.sun)).degrees < 0.267)
		#expect((behind.deflected - behind.direction).length * Self.uas <= 0.1)
	}
}
