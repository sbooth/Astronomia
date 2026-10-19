//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct ELPMPP02Tests {
	static func vector(_ values: [Double]) -> Vector3 {
		Vector3(values[0], values[1], values[2])
	}

	/// The largest component of the difference between a vector and three values.
	static func difference(_ v: Vector3, _ values: [Double]) -> Double {
		let d = v - vector(values)
		return max(abs(d.x), abs(d.y), abs(d.z))
	}

	/// The angle between the directions of two vectors, in milliarcseconds.
	static func milliarcseconds(_ a: Vector3, _ b: Vector3) -> Double {
		let d = a - b
		let cross = Vector3(b.y * d.z - b.z * d.y, b.z * d.x - b.x * d.z, b.x * d.y - b.y * d.x)
		return Angle(radians: cross.length / (b.length * b.length)).milliarcseconds
	}

	@Test func seriesMatchTheData() {
		// The built-in series, summed in the order of ELPMPP02.for by an independent
		// implementation. That implementation forms each term's argument as a polynomial, where
		// this one sums multiples of the reduced fundamental arguments, so the two differ by
		// millimeters ten centuries from J2000.0.
		for value in elpmpp02Reference {
			let state = ELPMPP02.seriesState(at: value.days, fit: value.fit)
			#expect(Self.difference(state.position, value.position) <= 1e-5, "\(value.fit) \(value.days)")
			#expect(Self.difference(state.velocity, value.velocity) <= 2e-6, "\(value.fit) \(value.days)")
		}
	}

	@Test func truncationAgainstTheFullSeries() throws {
		// ELPMPP02.TXT comes from the full series, printed to 1e-7 km. The built-in series are
		// truncated for about 0.2 mas in direction and 10 m in distance.
		var checked = 0
		for value in elpmpp02CheckValues {
			let date = try JulianDate(julianDate: value.julianDate)
			guard ELPMPP02.coverage.contains(date) else { continue }
			let state = ELPMPP02.seriesState(at: date.daysSinceJ2000, fit: value.fit)
			let check = Self.vector(value.position)
			#expect(Self.milliarcseconds(state.position, check) <= 0.25, "\(value.fit) \(value.julianDate)")
			#expect(abs(state.position.length - check.length) <= 0.01, "\(value.fit) \(value.julianDate)")
			#expect(Self.difference(state.velocity, value.velocity) <= 0.01, "\(value.fit) \(value.julianDate)")
			checked += 1
		}
		#expect(checked == 24)
	}

	@Test func agreesWithDE421() throws {
		// With the published frame angles, the fit to DE405 agrees with DE421 from 1950 to 2050
		// to 12 mas. The fit to lunar laser ranging differs by about 40 mas, mostly in its
		// origin of longitudes.
		for value in de421Moon {
			let date = try JulianDate(julianDate: value.julianDate)
			let check = Self.vector(value.position) * (1 / Distance.kilometersPerAstronomicalUnit)
			for (fit, limit) in [(ELPMPP02.Fit.laserRanging, 55.0), (.de405, 13)] {
				let state = try #require(ELPMPP02.state(at: date, fit: fit))
				#expect(Self.milliarcseconds(state.position, check) <= limit, "\(fit) \(value.julianDate)")
			}
		}
	}

	@Test func icrsState() throws {
		let date = try JulianDate(julianDate: 2_460_000.5)
		for fit in [ELPMPP02.Fit.laserRanging, .de405] {
			let series = ELPMPP02.seriesState(at: date.daysSinceJ2000, fit: fit)
			let ecliptic = try #require(ELPMPP02.eclipticState(at: date, fit: fit))
			let icrs = try #require(ELPMPP02.state(at: date, fit: fit))
			// The ecliptic state is the series in astronomical units.
			let au = Distance.kilometersPerAstronomicalUnit
			#expect((ecliptic.position * au - series.position).length <= 1e-9)
			#expect((ecliptic.velocity * au - series.velocity).length <= 1e-9)
			#expect(icrs.position == fit.rotationToICRS.apply(to: ecliptic.position))
			#expect(icrs.velocity == fit.rotationToICRS.apply(to: ecliptic.velocity))
		}
	}

	@Test func publishedFrameAngles() {
		// The pole of each fit's ecliptic in the ICRS is at declination 90° - ε and right
		// ascension 270° + φ, from the angles of Chapront et al. (2002).
		for (fit, epsilon, phi) in [(ELPMPP02.Fit.laserRanging, 84_381.411_00, -0.055_42), (.de405, 84_381.409_60, -0.050_28)] {
			let pole = Position<ICRS>(fit.rotationToICRS.apply(to: Vector3(0, 0, 1))).spherical
			#expect(abs(pole.latitude.arcseconds - (324_000 - epsilon)) <= 1e-9, "\(fit)")
			#expect(abs(pole.longitude.arcseconds - (972_000 + phi)) <= 1e-8, "\(fit)")
			// The ecliptic's x axis, its ascending node, is on the equator at right ascension φ.
			let node = Position<ICRS>(fit.rotationToICRS.apply(to: Vector3(1, 0, 0))).spherical
			#expect(abs(node.latitude.arcseconds) <= 1e-9 && abs(node.longitude.normalizedSigned().arcseconds - phi) <= 1e-9, "\(fit)")
		}
	}

	@Test func velocityIsTheDerivative() {
		// The analytic velocity agrees with a central difference of the positions.
		for days in [-300_000.0, -1000, 0, 8000.25, 350_000] {
			let h = 0.01
			let state = ELPMPP02.seriesState(at: days, fit: .laserRanging)
			let after = ELPMPP02.seriesState(at: days + h, fit: .laserRanging).position
			let before = ELPMPP02.seriesState(at: days - h, fit: .laserRanging).position
			let numeric = (after - before) * (1 / (2 * h))
			#expect((state.velocity - numeric).length <= 1e-4 * state.velocity.length, "\(days)")
		}
	}

	@Test func coverage() throws {
		let start = ELPMPP02.coverage.lowerBound
		let end = ELPMPP02.coverage.upperBound
		#expect(ELPMPP02.state(at: start, fit: .laserRanging) != nil)
		#expect(ELPMPP02.state(at: end, fit: .de405) != nil)
		#expect(try ELPMPP02.state(at: start.adding(seconds: -1), fit: .laserRanging) == nil)
		#expect(try ELPMPP02.state(at: end.adding(seconds: 1), fit: .de405) == nil)
		#expect(start.daysSinceJ2000 == -365_250 && end.daysSinceJ2000 == 365_250)
	}

	@Test func termCounts() {
		let solution = ELPMPP02.Solution.laserRanging
		#expect(solution.mainTerms.count == 2_447)
		#expect(solution.perturbationTerms.count == 23_328)
		#expect(solution.mainAmplitudes.count == solution.mainTerms.count)
	}
}
