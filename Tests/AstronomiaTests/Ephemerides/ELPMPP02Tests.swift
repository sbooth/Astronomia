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
			let state = value.fit.seriesState(at: value.days)
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
			guard builtInEphemerisCoverage.contains(date) else { continue }
			let state = value.fit.seriesState(at: date.daysSinceJ2000)
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
			for (fit, limit) in [(ELPFit.laserRanging, 55.0), (.de405, 13)] {
				let state = try #require(fit.icrsState(at: date))
				#expect(Self.milliarcseconds(state.position, check) <= limit, "\(fit) \(value.julianDate)")
			}
		}
	}

	@Test func icrsState() throws {
		let date = try JulianDate(julianDate: 2_460_000.5)
		for fit in [ELPFit.laserRanging, .de405] {
			let series = fit.seriesState(at: date.daysSinceJ2000)
			let ecliptic = try #require(fit.eclipticState(at: date))
			let icrs = try #require(fit.icrsState(at: date))
			// The ecliptic state is the series in astronomical units.
			let au = Distance.kilometersPerAstronomicalUnit
			#expect((ecliptic.position * au - series.position).length <= 1e-9)
			#expect((ecliptic.velocity * au - series.velocity).length <= 1e-9)
			#expect(icrs.position == fit.icrs(ecliptic.position))
			#expect(icrs.velocity == fit.icrs(ecliptic.velocity))
		}
	}

	/// Expects a frame's pole in the ICRS at declination 90° - ε and right ascension 270° + φ,
	/// and its x axis, the ascending node of the ecliptic, on the equator at right ascension φ.
	static func expectFrameAngles<F: FixedReferenceFrame>(_ frame: F.Type, epsilon: Double, phi: Double, sourceLocation: SourceLocation = #_sourceLocation) {
		let pole = Position<F>(Vector3(0, 0, 1)).converted(to: ICRS.self).spherical
		#expect(abs(pole.latitude.arcseconds - (324_000 - epsilon)) <= 1e-9, sourceLocation: sourceLocation)
		#expect(abs(pole.longitude.arcseconds - (972_000 + phi)) <= 1e-8, sourceLocation: sourceLocation)
		let node = Position<F>(Vector3(1, 0, 0)).converted(to: ICRS.self).spherical
		#expect(abs(node.latitude.arcseconds) <= 1e-9, sourceLocation: sourceLocation)
		#expect(abs(node.longitude.normalizedSigned().arcseconds - phi) <= 1e-9, sourceLocation: sourceLocation)
	}

	@Test func publishedFrameAngles() {
		// The angles of Chapront et al. (2002), Table 9, and of VSOP2013
		Self.expectFrameAngles(ELPMPP02.LaserRanging.Ecliptic.self, epsilon: 84_381.411_00, phi: -0.055_42)
		Self.expectFrameAngles(ELPMPP02.DE405.Ecliptic.self, epsilon: 84_381.409_60, phi: -0.050_28)
		Self.expectFrameAngles(VSOP2013.Ecliptic.self, epsilon: 84_381.411_36, phi: -0.051_88)
		#expect(ELPMPP02.DE405.Frame.self == ELPMPP02.DE405.Ecliptic.self)
		#expect(ELPMPP02.LaserRanging.Frame.self == ELPMPP02.LaserRanging.Ecliptic.self)
	}

	/// Returns the five-point central difference of a function, with an error of order h⁴.
	static func derivative(_ f: (Double) -> Double, at t: Double, step h: Double) -> Double {
		(-f(t + 2 * h) + 8 * f(t + h) - 8 * f(t - h) + f(t - 2 * h)) / (12 * h)
	}

	@Test func velocityIsTheDerivative() {
		// The analytic velocity agrees with a five-point difference of the positions, with
		// steps of 0.02 day, to a few 1e-7 km/day near J2000.0.
		for fit in [ELPFit.laserRanging, .de405] {
			for days in [-7305.5, 0.25, 4000.25] {
				let velocity = fit.seriesState(at: days).velocity
				let x = Self.derivative({ fit.seriesState(at: $0).position.x }, at: days, step: 0.02)
				let y = Self.derivative({ fit.seriesState(at: $0).position.y }, at: days, step: 0.02)
				let z = Self.derivative({ fit.seriesState(at: $0).position.z }, at: days, step: 0.02)
				#expect((velocity - Vector3(x, y, z)).length <= 3e-6, "\(fit) \(days)")
			}
		}
	}

	@Test func radialVelocityIsTheDerivativeOfDistance() {
		// The rate of the distance is scaled as the distance is. Unscaled, as in ELPMPP02.for,
		// the radial velocity would be off by 5e-8 of itself, 1.3e-4 km/day or more at these
		// dates, where the five-point difference is good to 1e-5 km/day.
		for fit in [ELPFit.laserRanging, .de405] {
			for days in [-365_000.0, -100_000.3, -7305.5, 0.25, 250_000, 365_000] {
				let state = fit.seriesState(at: days)
				let radial = state.velocity.dot(state.position) / state.position.length
				#expect(abs(radial) >= 2500, "\(fit) \(days)")
				let numeric = Self.derivative({ fit.seriesState(at: $0).position.length }, at: days, step: 0.02)
				#expect(abs(radial - numeric) <= 2e-5, "\(fit) \(days)")
			}
		}
	}

	@Test func coverage() throws {
		let start = builtInEphemerisCoverage.lowerBound
		let end = builtInEphemerisCoverage.upperBound
		#expect(ELPFit.laserRanging.icrsState(at: start) != nil)
		#expect(ELPFit.de405.icrsState(at: end) != nil)
		#expect(try ELPFit.laserRanging.icrsState(at: start.adding(seconds: -1)) == nil)
		#expect(try ELPFit.de405.icrsState(at: end.adding(seconds: 1)) == nil)
		#expect(start.daysSinceJ2000 == -365_250 && end.daysSinceJ2000 == 365_250)
	}

	@Test func termCounts() {
		let series = ELPMPP02.LaserRanging.fittedSeries
		#expect(series.mainTerms.count == 2_447)
		#expect(series.perturbationTerms.count == 23_328)
		#expect(series.mainAmplitudes.count == series.mainTerms.count)
	}
}
