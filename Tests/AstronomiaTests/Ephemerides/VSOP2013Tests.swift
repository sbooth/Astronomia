//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct VSOP2013Tests {
	/// The largest component of the difference between a vector and three values.
	static func difference(_ v: Vector3, _ values: some Collection<Double>) -> Double {
		let w = Array(values)
		return max(abs(v.x - w[0]), abs(v.y - w[1]), abs(v.z - w[2]))
	}

	static func vector(_ values: some Collection<Double>) -> Vector3 {
		let w = Array(values)
		return Vector3(w[0], w[1], w[2])
	}

	@Test func elementsMatchTheData() throws {
		// The built-in series, summed as an independent implementation sums them
		for value in vsop2013CheckValues {
			let t = Double(value.julianDayNumber - 2_451_545) / daysPerJulianMillennium
			let elements = try VSOP2013.elements(of: #require(value.body.series), at: t)
			let actual = [elements.a, elements.meanLongitude, elements.k, elements.h, elements.q, elements.p]
			for (a, b) in zip(actual, value.elements) {
				#expect(abs(a - b) <= 1e-13, "\(value.body) \(value.julianDayNumber)")
			}
		}
	}

	@Test func statesMatchTheData() throws {
		for value in vsop2013CheckValues {
			let date = JulianDate(uncheckedJulianDayNumber: value.julianDayNumber, fractionFromNoon: 0)
			let state = try #require(VSOP2013.heliocentricState(of: value.body, at: date))
			#expect(Self.difference(state.position, value.position) <= 1e-12, "\(value.body) \(value.julianDayNumber)")
			#expect(Self.difference(state.velocity, value.velocity) <= 1e-15, "\(value.body) \(value.julianDayNumber)")
		}
	}

	@Test func truncationAgainstTheFullSeries() throws {
		// VSOP2013.ctl comes from the full series. The built-in series are truncated for about
		// 0.5 mas, or 1.5 mas for Pluto, whose solution is less accurate.
		for value in vsop2013CheckValues {
			let date = JulianDate(uncheckedJulianDayNumber: value.julianDayNumber, fractionFromNoon: 0)
			let state = try #require(VSOP2013.heliocentricState(of: value.body, at: date))
			let check = Self.vector(value.checkEcliptic.prefix(3))
			let angle = (state.position - check).length / check.length
			let limit = Angle.milliarcseconds(value.body == .plutoBarycenter ? 1.5 : 0.6).radians
			#expect(angle <= limit, "\(value.body) \(value.julianDayNumber): \(Angle(radians: angle).milliarcseconds) mas")
			// Velocities are printed to 1e-10 au/day
			#expect(Self.difference(state.velocity, value.checkEcliptic.suffix(3)) <= 2e-10, "\(value.body) \(value.julianDayNumber)")
		}
	}

	@Test func rotationToICRS() {
		// The check file's ecliptic values rotate to its ICRS values, to its printed precision.
		for value in vsop2013CheckValues {
			let position = VSOP2013.Ecliptic.rotationToICRS.apply(to: Self.vector(value.checkEcliptic.prefix(3)))
			let velocity = VSOP2013.Ecliptic.rotationToICRS.apply(to: Self.vector(value.checkEcliptic.suffix(3)))
			#expect(Self.difference(position, value.checkICRS.prefix(3)) <= 1.5e-10, "\(value.body) \(value.julianDayNumber)")
			#expect(Self.difference(velocity, value.checkICRS.suffix(3)) <= 1.5e-10, "\(value.body) \(value.julianDayNumber)")
		}
	}

	@Test func icrsState() throws {
		let value = vsop2013CheckValues[30]
		let date = JulianDate(uncheckedJulianDayNumber: value.julianDayNumber, fractionFromNoon: 0)
		let ecliptic = try #require(VSOP2013.heliocentricState(of: value.body, at: date))
		let icrs = try VSOP2013.Solution().state(of: value.body, at: Instant<TDB>(date)).converted(to: ICRS.self)
		#expect(icrs.position.vector == VSOP2013.Ecliptic.rotationToICRS.apply(to: ecliptic.position))
		#expect(icrs.velocity.vector == VSOP2013.Ecliptic.rotationToICRS.apply(to: ecliptic.velocity))
	}

	@Test func coverage() throws {
		let start = builtInEphemerisCoverage.lowerBound
		let end = builtInEphemerisCoverage.upperBound
		for body in [VSOP2013.Body.mars, .sun, .solarSystemBarycenter] {
			#expect(VSOP2013.heliocentricState(of: body, at: start) != nil)
			#expect(VSOP2013.heliocentricState(of: body, at: end) != nil)
			#expect(try VSOP2013.heliocentricState(of: body, at: start.adding(seconds: -1)) == nil)
			#expect(try VSOP2013.heliocentricState(of: body, at: end.adding(seconds: 1)) == nil)
		}
		// J1000.0 and J3000.0 are a thousand Julian years either side of J2000.0.
		#expect(start.daysSinceJ2000 == -365_250 && end.daysSinceJ2000 == 365_250)
	}

	@Test func circularOrbit() {
		// With zero eccentricity and inclination the orbit is a circle in the plane.
		let gm = 2.959_122_083_684_143_826_9e-4
		for longitude in [0.0, 1, 2.5, 4, 6] {
			let state = EllipticElements(a: 2, meanLongitude: longitude, k: 0, h: 0, q: 0, p: 0).state(gm: gm)
			#expect(Self.difference(state.position, [2 * Math.cos(longitude), 2 * Math.sin(longitude), 0]) <= 1e-15)
			let speed = (gm / 2).squareRoot()
			#expect(Self.difference(state.velocity, [-speed * Math.sin(longitude), speed * Math.cos(longitude), 0]) <= 1e-17)
		}
	}

	@Test func termCounts() {
		let counts = VSOP2013.Body.allCases.compactMap(\.series).map(\.terms.termCount)
		#expect(VSOP2013.Body.sun.series == nil && VSOP2013.Body.solarSystemBarycenter.series == nil)
		#expect(counts == [5_735, 21_481, 32_666, 72_791, 43_148, 82_504, 60_725, 49_125, 51_884])
	}
}
