//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaData

/// A polynomial of degree 4 in time, in radians with time in Julian centuries.
struct ELPPolynomial: Sendable {
	/// The coefficients, from the constant term.
	let c0, c1, c2, c3, c4: Double

	/// Returns the value at a time, with the powers of time formed as `ELPMPP02.for` forms them.
	func value(at t: Double) -> Double {
		let t2 = t * t
		let t3 = t2 * t
		return c0 + c1 * t + c2 * t2 + c3 * t3 + c4 * (t3 * t)
	}

	/// Returns the derivative at a time, in radians per century.
	func rate(at t: Double) -> Double {
		let t2 = t * t
		return c1 + 2 * c2 * t + 3 * c3 * t2 + 4 * c4 * (t2 * t)
	}
}

extension ELPMPP02 {
	/// The solution's series with the constants of a fit.
	struct FittedSeries: @unchecked Sendable {
		// The data is immutable, so the pointers into it can be shared.
		/// The series of the main problem.
		let mainSeries: UnsafeBufferPointer<astronomia_elp_series>
		/// The terms of the main problem.
		let mainTerms: UnsafeBufferPointer<astronomia_elp_main_term>
		/// The amplitudes of the main problem, corrected for the fit.
		let mainAmplitudes: [Double]
		/// The series of the perturbations.
		let perturbationSeries: UnsafeBufferPointer<astronomia_elp_series>
		/// The terms of the perturbations.
		let perturbationTerms: UnsafeBufferPointer<astronomia_elp_perturbation_term>
		/// The Moon's mean longitude W1.
		let meanLongitude: ELPPolynomial
		/// The thirteen fundamental arguments: D, F, l, l', the mean longitudes of Mercury to
		/// Neptune, and ζ.
		let arguments: [ELPPolynomial]
	}
}

extension ELPMPP02.FittedSeries {
	/// Returns sexagesimal degrees in radians.
	private static func radians(_ degrees: Double, _ minutes: Double, _ seconds: Double) -> Double {
		(degrees + minutes / 60 + seconds / 3600) * (Double.pi / 180)
	}

	/// Creates the series for a fit from the built-in data, following `INITIAL` and `READFILE`
	/// of `ELPMPP02.for`: the fit's corrections set the fundamental arguments and, through the
	/// partial derivatives, the amplitudes of the main problem.
	///
	/// - Parameter corrections: The fit's corrections to the nominal constants.
	init(corrections: ELPMPP02.Corrections) {
		let data = astronomia_elpmpp02
		let rad = arcsecondsPerRadian
		let (dw10, dw20, dw30, dEarth0, dPerihelion) = (corrections.w10, corrections.w20, corrections.w30, corrections.earth0, corrections.perihelion0)
		let (dw11, dGamma, dE, dEarth1, dEp) = (corrections.w11, corrections.gamma, corrections.e, corrections.earth1, corrections.eccentricity)
		let (dw21, dw31, dw12) = (corrections.w21, corrections.w31, corrections.w12)

		// The mean longitudes of the Moon W1, of its perigee W2, and of its node W3, and of the
		// Earth-Moon barycenter and its perihelion
		var w1 = [Self.radians(218, 18, 59.955_71 + dw10), (1_732_559_343.736_04 + dw11) / rad, (-6.8084 + dw12) / rad, 0.660_40e-2 / rad, -0.316_90e-4 / rad]
		var w2 = [Self.radians(83, 21, 11.674_75 + dw20), (14_643_420.3171 + dw21) / rad, -38.2631 / rad, -0.450_47e-1 / rad, 0.213_01e-3 / rad]
		var w3 = [Self.radians(125, 2, 40.398_16 + dw30), (-6_967_919.5383 + dw31) / rad, 6.3590 / rad, 0.762_50e-2 / rad, -0.358_60e-4 / rad]
		let earth = [Self.radians(100, 27, 59.138_85 + dEarth0), (129_597_742.293_00 + dEarth1) / rad, -0.020_200 / rad, 0.900_00e-5 / rad, 0.150_00e-6 / rad]
		let perihelion = [Self.radians(102, 56, 14.457_66 + dPerihelion), 1161.243_42 / rad, 0.529_265 / rad, -0.118_14e-3 / rad, 0.113_79e-4 / rad]

		// The corrections to the secular terms of the lunar angles that follow DE405
		if let secular = corrections.secular {
			w1[3] = w1[3] + secular.w13 / rad
			w1[4] = w1[4] + secular.w14 / rad
			w2[2] = w2[2] + secular.w22 / rad
			w2[3] = w2[3] + secular.w23 / rad
			w3[2] = w3[2] + secular.w32 / rad
			w3[3] = w3[3] + secular.w33 / rad
		}

		// The corrections to the mean motions of W2 and W3 that follow from the corrections to
		// the constants
		let am = 0.074_801_329
		let alpha = 0.002_571_881
		let dtasm = (2 * alpha) / (3 * am)
		let xa = (2 * alpha) / 3
		let bp = [(0.311_079_095, -0.448_239_8e-2, -0.110_248_500e-2, 0.105_606_2e-2, 0.509_28e-4),
		          (-0.103_837_907, 0.668_287_0e-3, -0.129_807_200e-2, -0.178_028_0e-3, -0.373_42e-4)]
		let x2 = w2[1] / w1[1]
		let x3 = w3[1] / w1[1]
		let y2 = am * bp[0].0 + xa * bp[0].4
		let y3 = am * bp[1].0 + xa * bp[1].4
		let cw21 = (x2 - y2) * dw11 + y2 / am * dEarth1 + w1[1] * bp[0].1 * dGamma + w1[1] * bp[0].2 * dE + w1[1] * bp[0].3 * dEp
		let cw31 = (x3 - y3) * dw11 + y3 / am * dEarth1 + w1[1] * bp[1].1 * dGamma + w1[1] * bp[1].2 * dE + w1[1] * bp[1].3 * dEp
		w2[1] = w2[1] + cw21 / rad
		w3[1] = w3[1] + cw31 / rad

		func polynomial(_ c: [Double]) -> ELPPolynomial {
			ELPPolynomial(c0: c[0], c1: c[1], c2: c[2], c3: c[3], c4: c[4])
		}

		// The Delaunay arguments D, F, l, l'
		let d = (0 ..< 5).map { w1[$0] - earth[$0] + ($0 == 0 ? Double.pi : 0) }
		let f = (0 ..< 5).map { w1[$0] - w3[$0] }
		let l = (0 ..< 5).map { w1[$0] - w2[$0] }
		let lp = (0 ..< 5).map { earth[$0] - perihelion[$0] }

		// The mean longitudes of the planets, from VSOP2000
		let planets: [(Double, Double)] = [
			(Self.radians(252, 15, 3.216_919), 538_101_628.668_88 / rad),
			(Self.radians(181, 58, 44.758_419), 210_664_136.457_77 / rad),
			(Self.radians(100, 27, 59.138_850), 129_597_742.293_00 / rad),
			(Self.radians(355, 26, 3.642_778), 68_905_077.659_36 / rad),
			(Self.radians(34, 21, 5.379_392), 10_925_660.573_35 / rad),
			(Self.radians(50, 4, 38.902_495), 4_399_609.336_32 / rad),
			(Self.radians(314, 3, 4.354_234), 1_542_482.578_45 / rad),
			(Self.radians(304, 20, 56.808_371), 786_547.897_00 / rad),
		]

		// ζ, the Moon's mean longitude with the rate of precession, IAU 2000A
		let precession = 5029.0966 - 0.299_65
		let zeta = [w1[0], w1[1] + precession / rad, w1[2], w1[3], w1[4]]

		meanLongitude = polynomial(w1)
		arguments = [polynomial(d), polynomial(f), polynomial(l), polynomial(lp)]
			+ planets.map { ELPPolynomial(c0: $0.0, c1: $0.1, c2: 0, c3: 0, c4: 0) }
			+ [polynomial(zeta)]

		// The corrections to ν, E, Γ, n', and e', by which the partial derivatives correct the
		// amplitudes of the main problem
		let dNu = (0.556_04 + dw11) / rad / w1[1]
		let dE2 = (0.017_89 + dE) / rad
		let dGamma2 = (-0.080_66 + dGamma) / rad
		let dNp = (-0.064_24 + dEarth1) / rad / w1[1]
		let dEp2 = (-0.128_79 + dEp) / rad

		mainSeries = UnsafeBufferPointer(start: data.main_series, count: data.main_series_count)
		mainTerms = UnsafeBufferPointer(start: data.main_terms, count: data.main_term_count)
		perturbationSeries = UnsafeBufferPointer(start: data.perturbation_series, count: data.perturbation_series_count)
		perturbationTerms = UnsafeBufferPointer(start: data.perturbation_terms, count: data.perturbation_term_count)

		var amplitudes: [Double] = []
		amplitudes.reserveCapacity(mainTerms.count)
		var index = 0
		for series in mainSeries {
			for _ in 0 ..< Int(series.counts.0) {
				let term = mainTerms[index]
				let b = term.partials
				let tgv = b.0 + dtasm * b.4
				var a = term.amplitude
				if series.variable == 3 {
					a = a - 2 * a * dNu / 3
				}
				amplitudes.append(a + tgv * (dNp - am * dNu) + b.1 * dGamma2 + b.2 * dE2 + b.3 * dEp2)
				index += 1
			}
		}
		mainAmplitudes = amplitudes
	}
}

extension ELPMPP02.FittedSeries {
	/// Returns the Moon's position and velocity, following `EVALUATE` of `ELPMPP02.for`.
	///
	/// Each series has its terms in order of decreasing amplitude, and the leading terms of
	/// the precision level are summed.
	///
	/// - Parameters:
	///   - t: TDB in Julian centuries from J2000.0.
	///   - precision: The precision level.
	/// - Returns: The position, in kilometers, and velocity, in kilometers per day, in the fit's
	///   inertial mean ecliptic and equinox of J2000.0.
	func state(at t: Double, precision: Precision = .full) -> (position: Vector3, velocity: Vector3) {
		let level = precision.level
		// The fundamental arguments, reduced to (-π, π], and their rates
		var x = [Double](repeating: 0, count: 13)
		var xp = [Double](repeating: 0, count: 13)
		for (k, argument) in arguments.enumerated() {
			x[k] = argument.value(at: t).remainder(dividingBy: twoPi)
			xp[k] = argument.rate(at: t)
		}
		let powers = [1, t, t * t, t * t * t]

		// The sums of longitude, latitude, and distance, and their derivatives
		var v = [0.0, 0.0, 0.0]
		var vp = [0.0, 0.0, 0.0]

		var start = 0
		for series in mainSeries {
			let variable = Int(series.variable) - 1
			var sum = v[variable]
			var rate = vp[variable]
			let count = Int(levelValue(series.counts, level))

			if count > 0 {
				let termPointer = mainTerms.baseAddress!.advanced(by: start)
				mainAmplitudes.withUnsafeBufferPointer {
					let amplitudePointer = $0.baseAddress!.advanced(by: start)
					let result = x.withUnsafeBufferPointer { xBuffer in
						xp.withUnsafeBufferPointer { xpBuffer in
							astronomia_elp_evaluate_main( termPointer, amplitudePointer, count, xBuffer.baseAddress!, xpBuffer.baseAddress!, variable == 2 ? 1 : 0, sum, rate)
						}
					}
					sum = result.sum
					rate = result.rate
				}
			}
			v[variable] = sum
			vp[variable] = rate
			start += Int(series.counts.0)
		}

		start = 0
		for series in perturbationSeries {
			let variable = Int(series.variable) - 1
			let power = Int(series.power)
			let tPower = powers[power]
			let tPowerRate = power == 0 ? 0 : Double(power) * powers[power - 1]
			var sum = v[variable]
			var rate = vp[variable]
			let count = Int(levelValue(series.counts, level))

			if count > 0 {
				let termPointer =
				perturbationTerms.baseAddress!.advanced(by: start)

				let result = x.withUnsafeBufferPointer { xBuffer in
					xp.withUnsafeBufferPointer { xpBuffer in
						astronomia_elp_evaluate_perturbation(termPointer, count, xBuffer.baseAddress!, xpBuffer.baseAddress!, tPower, tPowerRate, sum, rate)
					}
				}

				sum = result.sum
				rate = result.rate
			}
			v[variable] = sum
			vp[variable] = rate
			start += Int(series.counts.0)
		}

		return Self.rectangular(longitude: v[0], latitude: v[1], distance: v[2], rates: vp, meanLongitude: meanLongitude, at: t)
	}

	/// Returns rectangular coordinates referred to the ecliptic of J2000.0 from the sums of the
	/// series, following `EVALUATE` of `ELPMPP02.for`.
	///
	/// `ELPMPP02.for` scales the distance by the ratio of the semimajor axes of DE405 and ELP but
	/// not its rate, so its velocity differs from the derivative of its position by about 5e-8
	/// of the radial velocity, up to 3e-4 km/day. Both are scaled here.
	private static func rectangular(longitude: Double, latitude: Double, distance: Double, rates: [Double], meanLongitude: ELPPolynomial, at t: Double) -> (position: Vector3, velocity: Vector3) {
		let rad = arcsecondsPerRadian
		// The ratio of the semimajor axes of DE405 and ELP, which scales the distance
		let a405 = 384_747.961_370_172_5
		let aelp = 384_747.980_674_318

		let lambda = longitude / rad + meanLongitude.value(at: t)
		let beta = latitude / rad
		let r = distance * a405 / aelp
		let lambdaRate = rates[0] / rad + meanLongitude.rate(at: t)
		let betaRate = rates[1] / rad
		let rRate = rates[2] * a405 / aelp

		let (slamb, clamb) = Math.sincos(lambda)
		let (sbeta, cbeta) = Math.sincos(beta)
		let cw = r * cbeta
		let sw = r * sbeta
		let x1 = cw * clamb
		let x2 = cw * slamb
		let x3 = sw
		let xp1 = (rRate * cbeta - betaRate * sw) * clamb - lambdaRate * x2
		let xp2 = (rRate * cbeta - betaRate * sw) * slamb + lambdaRate * x1
		let xp3 = rRate * sbeta + betaRate * cw

		// The precession of the ecliptic of date on the ecliptic of J2000.0 (Laskar 1986)
		let (p1, p2, p3, p4, p5) = (0.101_803_91e-4, 0.470_204_39e-6, -0.541_736_7e-9, -0.250_794_8e-11, 0.463_486e-14)
		let (q1, q2, q3, q4, q5) = (-0.113_469_002e-3, 0.123_726_74e-6, 0.126_541_7e-8, -0.137_180_8e-11, -0.320_334e-14)
		let t2 = t * t
		let t3 = t2 * t
		let t4 = t3 * t
		let pw = (p1 + p2 * t + p3 * t2 + p4 * t3 + p5 * t4) * t
		let qw = (q1 + q2 * t + q3 * t2 + q4 * t3 + q5 * t4) * t
		let ra = 2 * (1 - pw * pw - qw * qw).squareRoot()
		let pwqw = 2 * pw * qw
		let pw2 = 1 - 2 * pw * pw
		let qw2 = 1 - 2 * qw * qw
		let pwra = pw * ra
		let qwra = qw * ra

		let position = Vector3(
			pw2 * x1 + pwqw * x2 + pwra * x3,
			pwqw * x1 + qw2 * x2 - qwra * x3,
			-pwra * x1 + qwra * x2 + (pw2 + qw2 - 1) * x3
		)

		let ppw = p1 + (2 * p2 + 3 * p3 * t + 4 * p4 * t2 + 5 * p5 * t3) * t
		let qpw = q1 + (2 * q2 + 3 * q3 * t + 4 * q4 * t2 + 5 * q5 * t3) * t
		let ppw2 = -4 * pw * ppw
		let qpw2 = -4 * qw * qpw
		let ppwqpw = 2 * (ppw * qw + pw * qpw)
		let rap = (ppw2 + qpw2) / ra
		let ppwra = ppw * ra + pw * rap
		let qpwra = qpw * ra + qw * rap

		let sc = daysPerJulianCentury
		let velocity = Vector3(
			(pw2 * xp1 + pwqw * xp2 + pwra * xp3 + ppw2 * x1 + ppwqpw * x2 + ppwra * x3) / sc,
			(pwqw * xp1 + qw2 * xp2 - qwra * xp3 + ppwqpw * x1 + qpw2 * x2 - qpwra * x3) / sc,
			(-pwra * xp1 + qwra * xp2 + (pw2 + qw2 - 1) * xp3 - ppwra * x1 + qpwra * x2 + (ppw2 + qpw2) * x3) / sc
		)
		return (position, velocity)
	}
}
