//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct StarTests {
	/// Microarcseconds per radian.
	static let uas = microarcsecondsPerRadian

	/// Returns a fixture star, optionally without its radial velocity.
	static func star(_ index: Int, withoutRadialVelocity: Bool = false) throws -> Star {
		let s = fixtureStars[index]
		return try Star(
			rightAscension: .degrees(s.rightAscension),
			declination: .degrees(s.declination),
			properMotionInRightAscension: .milliarcseconds(s.properMotionInRightAscension),
			properMotionInDeclination: .milliarcseconds(s.properMotionInDeclination),
			parallax: s.parallax.map { .milliarcseconds($0) },
			radialVelocity: .kilometersPerSecond(withoutRadialVelocity ? 0 : s.radialVelocity),
			epoch: Instant(JulianDate(julianEpoch: s.julianEpoch)))
	}

	/// Returns the angle between two vectors, in µas.
	static func separation(_ a: Vector3, _ b: Vector3) -> Double {
		Math.atan2(a.cross(b).length, a.dot(b)) * uas
	}

	static func vector(_ v: [Double]) -> Vector3 {
		Vector3(v[0], v[1], v[2])
	}

	static func direction(rightAscension: Double, declination: Double) -> Vector3 {
		let (sinA, cosA) = Math.sincos(rightAscension)
		let (sinD, cosD) = Math.sincos(declination)
		return Vector3(cosD * cosA, cosD * sinA, sinD)
	}

	@Test func validation() throws {
		let epoch = Instant<TDB>(.J2000)
		let star = try Star(rightAscension: .degrees(10), declination: .degrees(-90), epoch: epoch)
		#expect(star.parallax == nil && star.radialVelocity == .zero && star.properMotionInDeclination == .zero)
		#expect(throws: StarError.nonFiniteValue) { try Star(rightAscension: .degrees(.nan), declination: .zero, epoch: epoch) }
		#expect(throws: StarError.nonFiniteValue) { try Star(rightAscension: .zero, declination: .zero, properMotionInRightAscension: .degrees(.infinity), epoch: epoch) }
		#expect(throws: StarError.nonFiniteValue) { try Star(rightAscension: .zero, declination: .zero, parallax: .degrees(.nan), epoch: epoch) }
		#expect(throws: StarError.nonFiniteValue) { try Star(rightAscension: .zero, declination: .zero, radialVelocity: .kilometersPerSecond(-.infinity), epoch: epoch) }
		#expect(throws: StarError.invalidDeclination) { try Star(rightAscension: .zero, declination: .degrees(90.000_001), epoch: epoch) }
		#expect(throws: StarError.negativeParallax) { try Star(rightAscension: .zero, declination: .zero, parallax: .milliarcseconds(-0.1), epoch: epoch) }
		#expect(throws: StarError.excessiveRadialVelocity) { try Star(rightAscension: .zero, declination: .zero, radialVelocity: .kilometersPerSecond(-speedOfLight / 2), epoch: epoch) }
		#expect(try Star(rightAscension: .zero, declination: .zero, parallax: .zero, radialVelocity: .kilometersPerSecond(speedOfLight * 0.49), epoch: epoch).parallax == .zero)
	}

	@Test func motionMatchesERFA() throws {
		for row in erfaStarMotion {
			let star = try Self.star(row.star)
			let moved = star.propagated(to: Instant(try JulianDate(julianEpoch: row.julianEpoch)))
			let direction = Self.direction(rightAscension: moved.rightAscension.radians, declination: moved.declination.radians)
			#expect(Self.separation(direction, Self.direction(rightAscension: row.rightAscension, declination: row.declination)) <= 0.001)
			#expect(moved.rightAscension.radians >= 0 && moved.rightAscension.radians < twoPi)
			#expect(abs(moved.properMotionInRightAscension.radians - row.properMotionInRightAscension) * Self.uas <= 1e-6)
			#expect(abs(moved.properMotionInDeclination.radians - row.properMotionInDeclination) * Self.uas <= 1e-6)
			#expect(abs(moved.radialVelocity.kilometersPerSecond - row.radialVelocity) <= 1e-10)
			// A star without a parallax has none at the new epoch.
			if let parallax = moved.parallax {
				#expect(abs(parallax.radians * arcsecondsPerRadian / row.parallax - 1) <= 1e-14)
			} else {
				#expect(star.parallax == nil)
			}
		}
	}

	@Test func propagationAtTheEpochAndBack() throws {
		for index in fixtureStars.indices {
			let star = try Self.star(index)
			let same = star.propagated(to: star.epoch)
			#expect(Self.separation(Self.direction(rightAscension: same.rightAscension.radians, declination: same.declination.radians), Self.direction(rightAscension: star.rightAscension.radians, declination: star.declination.radians)) <= 0.001)
			#expect(abs(same.properMotionInRightAscension.radians - star.properMotionInRightAscension.radians) * Self.uas <= 1e-6)
			#expect(abs(same.properMotionInDeclination.radians - star.properMotionInDeclination.radians) * Self.uas <= 1e-6)
			#expect(abs(same.radialVelocity.kilometersPerSecond - star.radialVelocity.kilometersPerSecond) <= 1e-10)
			let back = star.propagated(to: Instant(try JulianDate(julianEpoch: 2100))).propagated(to: star.epoch)
			#expect(Self.separation(Self.direction(rightAscension: back.rightAscension.radians, declination: back.declination.radians), Self.direction(rightAscension: star.rightAscension.radians, declination: star.declination.radians)) <= 0.001)
			#expect(back.epoch == star.epoch)
		}
	}

	@Test func placesMatchERFA() throws {
		for row in erfaStarPlaces {
			let star = try Self.star(row.star)
			let tdb = Instant<TDB>(try JulianDate(julianDate: row.julianDate))
			let astrometric = try Observer.geocenter.astrometricPlace(of: star, at: tdb)
			let apparent = try Observer.geocenter.apparentPlace(of: star, at: tdb)
			#expect(Self.separation(astrometric.position.vector, Self.vector(row.astrometric)) <= 0.02)
			#expect(Self.separation(apparent.position.vector, Self.vector(row.apparent)) <= 0.3)
			#expect(apparent.lightTime == astrometric.lightTime && apparent.instant == astrometric.instant)
		}
	}

	@Test func placesMatchSkyfield() throws {
		// Skyfield's model agrees with ERFA's for stars without radial velocity.
		for row in skyfieldStarPlaces {
			let star = try Self.star(row.star, withoutRadialVelocity: true)
			let tdb = Instant<TDB>(try JulianDate(julianDate: row.julianDate))
			let astrometric = try Observer.geocenter.astrometricPlace(of: star, at: tdb)
			let apparent = try Observer.geocenter.apparentPlace(of: star, at: tdb)
			let reference = Self.vector(row.astrometric)
			#expect(Self.separation(astrometric.position.vector, reference) <= 0.2)
			#expect(abs(astrometric.position.vector.length / reference.length - 1) <= 1e-6)
			#expect(abs(astrometric.lightTime.inDays / row.lightTime - 1) <= 1e-6)
			#expect(Self.separation(apparent.position.vector, Self.vector(row.apparent)) <= 0.6)
		}
	}

	@Test func starsWithoutParallax() throws {
		let quasar = try Self.star(5)
		let moving = try Self.star(6)
		let barnard = try Self.star(0)
		#expect(!quasar.hasDistance && !moving.hasDistance && barnard.hasDistance)
		// The motion of a star without a parallax is taken where its transverse speed is 1% of c.
		let speed = 1 / moving.effectiveParallax * (50 * Angle(milliarcseconds: 1).radians) / daysPerJulianYear
		#expect(abs(speed / speedOfLightAstronomicalUnitsPerDay - 0.01) <= 0.000_01)
		#expect(quasar.effectiveParallax == Star.minimumParallax)
		// Its place is at the nominal distance of 1 Gpc.
		let tdb = Instant<TDB>(try JulianDate(julianDate: 2_461_334.5))
		let place = try Observer.geocenter.astrometricPlace(of: moving, at: tdb)
		let gigaparsec = 1e9 * arcsecondsPerRadian
		#expect(abs(place.position.vector.length / gigaparsec - 1) <= 1e-12)
		#expect(abs(place.lightTime.inDays * speedOfLightAstronomicalUnitsPerDay / gigaparsec - 1) <= 1e-12)
		#expect(moving.propagated(to: tdb).parallax == nil)
	}

	@Test func deflectionNearTheSun() throws {
		// Stars just off the Sun's limb and behind its disk, which Jupiter and Saturn still
		// deflect by about 1 µas
		let tdb = Instant<TDB>(try JulianDate(julianDate: 2_461_334.5))
		let sun = try Observer.geocenter.astrometricPlace(of: .sun, at: tdb).position.spherical
		for (offset, expected) in [(0.3, 1.751 * 0.2666 / 0.3), (1.0, 1.751 * 0.2666 / 1.0), (0.1, 0)] {
			let star = try Star(rightAscension: sun.rightAscension, declination: Angle(radians: sun.declination.radians + offset * .pi / 180), epoch: tdb)
			let ephemeris = SolarSystemEphemeris()
			let (_, geometry, positions) = try Observer.geocenter.observe(star, at: tdb, context: TDB.defaultContext, ephemeris: ephemeris)
			let direction = geometry.target - geometry.observer.position
			let undeflected = direction / direction.length
			let deflected = try Astrometry.deflected(undeflected, geometry: geometry, of: nil, positions: positions)
			let deflection = Self.separation(undeflected, deflected) / 1e6
			#expect(abs(deflection - expected) <= max(0.01 * expected, 2e-6))
		}
	}
}
