//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaData

/// The IAU 2006 precession (Capitaine et al. 2003) and IAU 2000A_R06 nutation (Mathews et al.
/// 2002, with the IAU 2006 adjustments), as given in the IERS Conventions (2010), Chapter 5.
///
/// Precession is expressed by the Fukushima-Williams angles, which include the frame bias, and
/// nutation by its components in longitude and obliquity. Their time argument is TT.
///
/// The frames of date, such as ``TrueEquatorOfDate`` and ``CIRS``, and the sidereal times of
/// ``EarthRotation`` follow this model. The quantities here are for classical calculations
/// that need them directly:
///
/// ```swift
/// let nutation = IAU2006.nutation(at: tt)
/// let trueObliquity = IAU2006.meanObliquity(at: tt) + nutation.obliquity
/// ```
///
/// - Note: Petit, G., Luzum, B. (eds.) (2010). IERS Conventions (2010). IERS Technical Note
///   No. 36.
public enum IAU2006 {
	/// The nutation in longitude Δψ, IAU 2000A_R06, from Table 5.3a.
	static let nutationInLongitude = SeriesData(astronomia_iau2006_nutation_longitude)
	/// The nutation in obliquity Δε, IAU 2000A_R06, from Table 5.3b.
	static let nutationInObliquity = SeriesData(astronomia_iau2006_nutation_obliquity)
	/// The CIO locator s plus XY/2, from Table 5.2d.
	static let sPlusHalfXY = SeriesData(astronomia_iau2006_s_plus_half_xy)
}

extension IAU2006 {
	/// The fourteen fundamental arguments of the nutation series, in radians: the Delaunay
	/// arguments l, l', F, D, and Ω, the mean longitudes of Mercury to Neptune, and the general
	/// precession in longitude p_A.
	///
	/// The expressions are those of the IERS Conventions (2003), Eqs. (5.43) and (5.44), from
	/// Simon et al. (1994) and Souchay et al. (1999), which the tables of the IERS Conventions
	/// (2010) use for both their lunisolar and planetary terms.
	struct FundamentalArguments: Sendable {
		/// The arguments, reduced to a turn except p_A.
		let values: (Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double)

		/// Returns the fundamental arguments at a time.
		///
		/// - Parameter t: TT in Julian centuries from J2000.0.
		init(at t: Double) {
			let turn = 1_296_000.0
			/// Reduces a polynomial in arcseconds to a turn, in radians.
			func arcseconds(_ c0: Double, _ c1: Double, _ c2: Double, _ c3: Double, _ c4: Double) -> Double {
				(c0 + (c1 + (c2 + (c3 + c4 * t) * t) * t) * t).truncatingRemainder(dividingBy: turn) / arcsecondsPerRadian
			}
			/// Reduces a mean longitude in radians to a turn.
			func radians(_ c0: Double, _ c1: Double) -> Double {
				(c0 + c1 * t).truncatingRemainder(dividingBy: twoPi)
			}
			values = (
				// l, the mean anomaly of the Moon
				arcseconds(485_868.249_036, 1_717_915_923.217_8, 31.879_2, 0.051_635, -0.000_244_70),
				// l', the mean anomaly of the Sun
				arcseconds(1_287_104.793_048, 129_596_581.048_1, -0.553_2, 0.000_136, -0.000_011_49),
				// F, the mean longitude of the Moon less that of its node
				arcseconds(335_779.526_232, 1_739_527_262.847_8, -12.751_2, -0.001_037, 0.000_004_17),
				// D, the mean elongation of the Moon from the Sun
				arcseconds(1_072_260.703_692, 1_602_961_601.209_0, -6.370_6, 0.006_593, -0.000_031_69),
				// Ω, the mean longitude of the Moon's ascending node
				arcseconds(450_160.398_036, -6_962_890.543_1, 7.472_2, 0.007_702, -0.000_059_39),
				// The mean longitudes of Mercury to Neptune
				radians(4.402_608_842, 2_608.790_314_157_4),
				radians(3.176_146_697, 1_021.328_554_621_1),
				radians(1.753_470_314, 628.307_584_999_1),
				radians(6.203_480_913, 334.061_242_670_0),
				radians(0.599_546_497, 52.969_096_264_1),
				radians(0.874_016_757, 21.329_910_496_0),
				radians(5.481_293_872, 7.478_159_856_7),
				radians(5.311_886_287, 3.813_303_563_8),
				// p_A, the general accumulated precession in longitude
				(0.024_381_750 + 0.000_005_386_91 * t) * t
			)
		}
	}
}

extension IAU2006 {
	/// The Fukushima-Williams angles of the IAU 2006 precession, which include the frame bias.
	struct PrecessionAngles: Sendable {
		/// γ̄, the angle from the GCRS right ascension origin to the intersection of the
		/// ecliptic of date and the GCRS equator, in radians.
		let gamma: Double
		/// φ̄, the obliquity of the ecliptic of date on the GCRS equator, in radians.
		let phi: Double
		/// ψ̄, the precession angle from the intersection to the mean equinox of date, in radians.
		let psi: Double
		/// ε_A, the mean obliquity of the ecliptic of date, in radians.
		let epsilon: Double
	}

	/// Returns the Fukushima-Williams angles and the mean obliquity, from the IERS Conventions
	/// (2010), Eqs. (5.40) and (5.39).
	///
	/// - Parameter t: TT in Julian centuries from J2000.0.
	static func precessionAngles(at t: Double) -> PrecessionAngles {
		/// Evaluates a polynomial in arcseconds, in radians.
		func arcseconds(_ c: Double...) -> Double {
			var value = 0.0
			for coefficient in c.reversed() {
				value = value * t + coefficient
			}
			return value / arcsecondsPerRadian
		}
		return PrecessionAngles(
			gamma: arcseconds(-0.052_928, 10.556_378, 0.493_204_4, -0.000_312_38, -0.000_002_788, 0.000_000_026_0),
			phi: arcseconds(84_381.412_819, -46.811_016, 0.051_126_8, 0.000_532_89, -0.000_000_440, -0.000_000_017_6),
			psi: arcseconds(-0.041_775, 5_038.481_484, 1.558_417_5, -0.000_185_22, -0.000_026_452, -0.000_000_014_8),
			epsilon: arcseconds(84_381.406, -46.836_769, -0.000_183_1, 0.002_003_40, -0.000_000_576, -0.000_000_043_4)
		)
	}

	/// Returns the nutation in longitude and in obliquity, IAU 2000A_R06.
	///
	/// - Parameters:
	///   - t: TT in Julian centuries from J2000.0.
	///   - arguments: The fundamental arguments at `t`.
	/// - Returns: Δψ and Δε, in radians.
	static func nutation(at t: Double, arguments: FundamentalArguments) -> (longitude: Double, obliquity: Double) {
		let longitude = nutationInLongitude.value(at: t, arguments: arguments)
		let obliquity = nutationInObliquity.value(at: t, arguments: arguments)
		return (longitude / microarcsecondsPerRadian, obliquity / microarcsecondsPerRadian)
	}

	/// Returns the rotation from the GCRS to the true equator and equinox of date, the product
	/// of the frame bias, precession, and nutation: R1(-(ε_A + Δε)) R3(-(ψ̄ + Δψ)) R1(φ̄) R3(γ̄).
	///
	/// - Parameters:
	///   - angles: The Fukushima-Williams angles.
	///   - nutation: Δψ and Δε, in radians.
	static func biasPrecessionNutation(angles: PrecessionAngles, nutation: (longitude: Double, obliquity: Double)) -> Rotation<ICRS, ICRS> {
		typealias R = Rotation<ICRS, ICRS>
		return R.aboutX(Angle(radians: -(angles.epsilon + nutation.obliquity)))
			* R.aboutZ(Angle(radians: -(angles.psi + nutation.longitude)))
			* R.aboutX(Angle(radians: angles.phi))
			* R.aboutZ(Angle(radians: angles.gamma))
	}

	/// Returns the CIO locator s, from the series for s + XY/2 of the IERS Conventions (2010),
	/// Table 5.2d.
	///
	/// - Parameters:
	///   - t: TT in Julian centuries from J2000.0.
	///   - arguments: The fundamental arguments at `t`.
	///   - x: The X coordinate of the CIP, in radians.
	///   - y: The Y coordinate of the CIP, in radians.
	/// - Returns: s, in radians.
	static func cioLocator(at t: Double, arguments: FundamentalArguments, x: Double, y: Double) -> Double {
		sPlusHalfXY.value(at: t, arguments: arguments) / microarcsecondsPerRadian - x * y / 2
	}

	/// Returns the equation of the origins, the angle from the CIO to the true equinox of date
	/// along the equator, following `eraEors` of ERFA (Wallace and Capitaine 2006).
	///
	/// Greenwich apparent sidereal time is the Earth rotation angle less the equation of the
	/// origins, as the IERS Conventions (2010), Eq. (5.31), define it.
	///
	/// - Parameters:
	///   - matrix: The rotation from the GCRS to the true equator and equinox of date.
	///   - s: The CIO locator, in radians.
	/// - Returns: The equation of the origins, in radians.
	static func equationOfOrigins(matrix: Rotation<ICRS, ICRS>, s: Double) -> Double {
		let (r0, r1, r2) = (matrix.storage.0, matrix.storage.1, matrix.storage.2)
		// The CIO, from the CIP's X coordinate and the pole of date, r2
		let x = r2.x
		let ax = x / (1 + r2.z)
		let cio = Vector3(1 - ax * x, -ax * r2.y, -x)
		let p = r0.dot(cio)
		let q = r1.dot(cio)
		return p != 0 || q != 0 ? s - Math.atan2(q, p) : s
	}
}
