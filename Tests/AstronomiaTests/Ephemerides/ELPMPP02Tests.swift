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
		// The rotation to the ICRS is fitted to DE421 from 1950 to 2050, where the two agree to
		// 12 mas with either fit.
		for value in de421Moon {
			let date = try JulianDate(julianDate: value.julianDate)
			let check = Self.vector(value.position) * (1 / Distance.kilometersPerAstronomicalUnit)
			for fit in [ELPMPP02.Fit.laserRanging, .de405] {
				let state = try #require(ELPMPP02.state(at: date, fit: fit))
				#expect(Self.milliarcseconds(state.position, check) <= 15, "\(fit) \(value.julianDate)")
			}
		}
	}

	@Test func icrsState() throws {
		let date = try JulianDate(julianDate: 2_460_000.5)
		for fit in [ELPMPP02.Fit.laserRanging, .de405] {
			let series = ELPMPP02.seriesState(at: date.daysSinceJ2000, fit: fit)
			let ecliptic = try #require(ELPMPP02.eclipticState(at: date, fit: fit))
			let icrs = try #require(ELPMPP02.state(at: date, fit: fit))
			// The fit's origin of longitudes moves the Moon along the ecliptic only.
			let au = Distance.kilometersPerAstronomicalUnit
			#expect(abs(ecliptic.position.z * au - series.position.z) <= 1e-9)
			#expect(abs(ecliptic.position.length * au - series.position.length) <= 1e-9)
			let offset = Angle(radians: (ecliptic.position * au - series.position).length / series.position.length)
			#expect(abs(offset.arcseconds - fit.longitudeOffset.arcseconds) <= 1e-6)
			#expect(icrs.position == ELPMPP02.rotationToICRS.apply(to: ecliptic.position))
			#expect(icrs.velocity == ELPMPP02.rotationToICRS.apply(to: ecliptic.velocity))
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
