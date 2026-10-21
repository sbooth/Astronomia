//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct IAU2006Tests {
	/// Microarcseconds per radian.
	static let uas = microarcsecondsPerRadian

	/// The values of the model at a reference date.
	struct Model {
		let t: Double
		let arguments: IAU2006.FundamentalArguments
		let angles: IAU2006.PrecessionAngles
		let nutation: (longitude: Double, obliquity: Double)
		let matrix: Rotation<ICRS, ICRS>

		init(julianDate: Double) throws {
			t = try JulianDate(julianDate: julianDate).julianCenturiesSinceJ2000
			arguments = IAU2006.FundamentalArguments(at: t)
			angles = IAU2006.precessionAngles(at: t)
			nutation = IAU2006.nutation(at: t, arguments: arguments)
			matrix = IAU2006.biasPrecessionNutation(angles: angles, nutation: nutation)
		}
	}

	/// The agreement of the nutation series with ERFA, in microarcseconds.
	///
	/// ERFA applies the IAU 2006 adjustments to every term of IAU 2000A, where the tables of the
	/// IERS Conventions list the adjustments above their 0.1 µas cutoff. The adjustments grow
	/// with time, so the series agree to about 0.2 µas at J2000.0, a few µas within a century,
	/// and 47 µas at J1000.0 and J3000.0.
	static func nutationTolerance(at t: Double) -> Double {
		6 * max(1, abs(t))
	}

	@Test func precessionAnglesMatchERFA() throws {
		// pfw06 and obl06 evaluate the same polynomials.
		for value in erfaIAU2006 {
			let model = try Model(julianDate: value.julianDate)
			let angles = [model.angles.gamma, model.angles.phi, model.angles.psi, model.angles.epsilon]
			for (angle, expected) in zip(angles, value.angles) {
				#expect(abs(angle - expected) * Self.uas <= 1e-4, "\(value.julianDate)")
			}
		}
	}

	@Test func nutationMatchesERFA() throws {
		for value in erfaIAU2006 {
			let model = try Model(julianDate: value.julianDate)
			let tolerance = Self.nutationTolerance(at: model.t)
			#expect(abs(model.nutation.longitude - value.nutation[0]) * Self.uas <= tolerance, "\(value.julianDate)")
			#expect(abs(model.nutation.obliquity - value.nutation[1]) * Self.uas <= 3, "\(value.julianDate)")
		}
	}

	@Test func nearThePresentNutationMatchesERFA() throws {
		// From 1950 to 2100 the series agree to a few microarcseconds.
		for value in erfaIAU2006 where (2_433_282.5 ... 2_488_070).contains(value.julianDate) {
			let model = try Model(julianDate: value.julianDate)
			#expect(abs(model.nutation.longitude - value.nutation[0]) * Self.uas <= 2.5, "\(value.julianDate)")
			#expect(abs(model.nutation.obliquity - value.nutation[1]) * Self.uas <= 0.5, "\(value.julianDate)")
		}
	}

	@Test func biasPrecessionNutationMatchesERFA() throws {
		// pnm06a, whose elements differ by the nutation in longitude times sin ε_A at most
		for value in erfaIAU2006 {
			let model = try Model(julianDate: value.julianDate)
			let rows = [model.matrix.rows.0, model.matrix.rows.1, model.matrix.rows.2]
			let tolerance = Self.nutationTolerance(at: model.t)
			for i in 0 ..< 3 {
				for j in 0 ..< 3 {
					#expect(abs(rows[i][j] - value.matrix[3 * i + j]) * Self.uas <= tolerance, "\(value.julianDate) \(i) \(j)")
				}
			}
		}
	}

	@Test func cioLocatorMatchesERFA() throws {
		// s06, from ERFA's X and Y, and s from these X and Y, agree to 0.3 µas.
		for value in erfaIAU2006 {
			let model = try Model(julianDate: value.julianDate)
			let s = IAU2006.cioLocator(at: model.t, arguments: model.arguments, x: value.cip[0], y: value.cip[1])
			#expect(abs(s - value.cip[2]) * Self.uas <= 0.3, "\(value.julianDate)")
			let x = model.matrix.storage.2.x
			let y = model.matrix.storage.2.y
			// X follows Δψ sin ε_A, and Y mostly Δε, with some of Δψ far from J2000.0.
			#expect(abs(x - value.cip[0]) * Self.uas <= Self.nutationTolerance(at: model.t), "\(value.julianDate)")
			#expect(abs(y - value.cip[1]) * Self.uas <= Self.nutationTolerance(at: model.t), "\(value.julianDate)")
		}
	}

	@Test func siderealTimeMatchesERFA() throws {
		// eo06a and gst06a, with UT1 equal to TT. The equation of the origins follows the
		// nutation in longitude, so it agrees as Δψ cos ε_A does.
		for value in erfaIAU2006 {
			let model = try Model(julianDate: value.julianDate)
			let x = model.matrix.storage.2.x
			let y = model.matrix.storage.2.y
			let s = IAU2006.cioLocator(at: model.t, arguments: model.arguments, x: x, y: y)
			let eo = IAU2006.equationOfOrigins(matrix: model.matrix, s: s)
			let tolerance = Self.nutationTolerance(at: model.t)
			#expect(abs(eo - value.siderealTime[3]) * Self.uas <= tolerance, "\(value.julianDate)")
			let era = try EarthRotation.earthRotationAngle(ut1: JulianDate(julianDate: value.julianDate)).radians
			let gst = (era - eo - value.siderealTime[2]).remainder(dividingBy: 2 * Double.pi)
			#expect(abs(gst) * Self.uas <= tolerance, "\(value.julianDate)")
		}
	}

	@Test func fundamentalArgumentsAtJ2000() {
		// At J2000.0 the arguments are the constant terms of the IERS Conventions (2003),
		// Eqs. (5.43) and (5.44).
		let arguments = IAU2006.FundamentalArguments(at: 0).values
		let rad = arcsecondsPerRadian
		#expect(arguments.0 == 485_868.249_036 / rad)
		#expect(arguments.4 == 450_160.398_036 / rad)
		#expect(arguments.5 == 4.402_608_842 && arguments.12 == 5.311_886_287)
		#expect(arguments.13 == 0)
	}

	@Test func builtInTables() {
		// The tables as published, with every term kept
		let longitude = IAU2006.nutationInLongitude
		#expect(longitude.termCount == 1_358 && longitude.series.map(\.count) == [1_320, 38])
		#expect(longitude.terms[0].s == -17_206_424.18 && longitude.terms[0].c == 3_338.60)
		#expect(longitude.polynomial == [0, 0, 0, 0, 0, 0])
		let obliquity = IAU2006.nutationInObliquity
		#expect(obliquity.termCount == 1_056 && obliquity.series.map(\.count) == [1_037, 19])
		#expect(obliquity.terms[0].s == 1_537.70 && obliquity.terms[0].c == 9_205_233.10)
		let s = IAU2006.sPlusHalfXY
		#expect(s.termCount == 66 && s.series.map(\.count) == [33, 3, 25, 4, 1])
		#expect(s.polynomial == [94.0, 3_808.65, -122.68, -72_574.11, 27.98, 15.62])
		for table in [longitude, obliquity, s] {
			#expect(table.threshold == 0 && table.span == 1_000 ... 3_000)
		}
	}
}
