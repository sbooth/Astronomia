//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import AstronomiaData

/// The lunar solution ELP/MPP02 (Chapront and Francou 2003).
///
/// The solution gives the geocentric longitude, latitude, and distance of the Moon as series in
/// TDB, whose arguments are polynomials in time. The constants of the solution are fitted either
/// to the DE405 ephemeris, ``DE405``, or to lunar laser ranging, ``LaserRanging``, and each fit
/// has its own realization of the ecliptic. ``Solution`` gives the Moon's state. The built-in
/// series are truncated for J1000.0 to J3000.0 so that the error from truncation is near
/// 0.2 mas in direction and 10 m in distance, well below the solution's own error.
///
/// - Note: Chapront, J., Francou, G. (2003). The lunar theory ELP revisited. Introduction of new
///   planetary perturbations. Astronomy & Astrophysics 404, 735.
public enum ELPMPP02 {
	/// A body of the solution.
	public enum Body: Hashable, Sendable, CaseIterable {
		/// The Earth.
		case earth
		/// The Moon.
		case moon
	}

	/// A fit of the solution's constants, with its realization of the solution's ecliptic.
	///
	/// The library defines the solution's two fits, ``DE405`` and ``LaserRanging``. A fit is a
	/// type, like a ``Timescale``, so that the frame of a ``Solution`` follows from its fit.
	public protocol Fit: Sendable {
		/// The fit's realization of the inertial mean ecliptic and equinox of J2000.0.
		associatedtype Ecliptic: EclipticFrame, FixedReferenceFrame

		/// The solution's series with the fit's constants.
		static var series: Series { get }
	}

	/// The solution's series with the constants of a fit.
	///
	/// The series exist so that each ``Fit`` carries its constants; only the library's fits
	/// create them.
	public struct Series: @unchecked Sendable {
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
		/// The thirteen fundamental arguments: D, F, l, l′, the mean longitudes of Mercury to
		/// Neptune, and ζ.
		let arguments: [ELPPolynomial]
	}

	/// The fit to the DE405 ephemeris from 1950 to 2060, with corrections to the secular terms
	/// of the lunar angles that follow DE405 over several thousand years.
	///
	/// With the published orientation of its frame, this fit agrees with modern ephemerides near
	/// the present to about 6 mas, so it is the library's default.
	public enum DE405: Fit {
		/// The inertial mean ecliptic and equinox of J2000.0 as realized by the fit.
		///
		/// The frame is the axes of DE405 rotated by R1(ε) R3(φ), with ε = 23° 26′ 21.40960″ and
		/// φ = -0.05028″ (Chapront et al. 2002, Table 9). The axes of DE405 are within a few
		/// milliarcseconds of the ICRS, so the frame is taken relative to the ICRS.
		///
		/// - Note: This is not ``EclipticJ2000``, the ecliptic of the IAU 2006 precession, from
		///   which it differs by a few milliarcseconds.
		public enum Ecliptic: EclipticFrame, FixedReferenceFrame {
			public static let name = "ELP/MPP02 (DE405) ecliptic J2000"

			public static let rotationFromICRS = Rotation<ICRS, Ecliptic>.aboutX(.arcseconds(84_381.409_60))
				* Rotation<ICRS, ICRS>.aboutZ(.arcseconds(-0.050_28))
		}

		/// The series with the constants fitted to DE405, from `ELPMPP02.for`.
		public static let series = Series(corrections: Corrections(
			w10: -0.070_08, w20: 0.207_94, w30: -0.072_15, earth0: -0.000_33, perihelion0: -0.007_49,
			w11: -0.351_06, gamma: 0.000_85, e: -0.000_06, earth1: 0.007_32, eccentricity: 0.002_24,
			w21: 0.080_17, w31: -0.043_17, w12: -0.037_43,
			secular: SecularCorrections(w13: -0.000_188_65, w14: -0.000_010_24, w22: 0.004_706_02, w23: -0.000_252_13, w32: -0.002_610_70, w33: -0.000_107_12)
		))
	}

	/// The fit to lunar laser ranging from 1970 to 2001, the default of the solution itself.
	///
	/// With the published orientation of its frame, this fit differs from modern ephemerides by
	/// about 40 mas, mostly in its origin of longitudes.
	public enum LaserRanging: Fit {
		/// The inertial mean ecliptic and equinox of J2000.0 as realized by the fit.
		///
		/// The frame is the ICRS rotated by R1(ε) R3(φ), with ε = 23° 26′ 21.41100″ and
		/// φ = -0.05542″ (Chapront et al. 2002, Table 9).
		///
		/// - Note: The angles come from the solution S2001, which precedes ELP/MPP02. Chapront and
		///   Francou (2003) note that the two fits differ mainly by their origin of longitudes,
		///   by about 0.036″. This is not ``EclipticJ2000``, the ecliptic of the IAU 2006
		///   precession.
		public enum Ecliptic: EclipticFrame, FixedReferenceFrame {
			public static let name = "ELP/MPP02 (LLR) ecliptic J2000"

			public static let rotationFromICRS = Rotation<ICRS, Ecliptic>.aboutX(.arcseconds(84_381.411_00))
				* Rotation<ICRS, ICRS>.aboutZ(.arcseconds(-0.055_42))
		}

		/// The series with the constants fitted to lunar laser ranging, from `ELPMPP02.for`.
		public static let series = Series(corrections: Corrections(
			w10: -0.105_25, w20: 0.168_26, w30: -0.107_60, earth0: -0.040_12, perihelion0: -0.048_54,
			w11: -0.323_11, gamma: 0.000_69, e: 0.000_05, earth1: 0.014_42, eccentricity: 0.002_26,
			w21: 0.080_17, w31: -0.043_17, w12: -0.037_94,
			secular: nil
		))
	}

	/// Julian days per Julian century, the unit of time of the series.
	static let daysPerCentury: Double = 36_525
}

extension ELPMPP02 {
	/// The corrections of a fit to the solution's nominal constants, in arcseconds and
	/// arcseconds per century to the power of the term.
	struct Corrections: Sendable {
		/// W1, W2, and W3, the mean longitudes of the Moon, its perigee, and its node, the mean
		/// longitude T of the Earth-Moon barycenter, and the longitude ϖ′ of its perihelion, at
		/// J2000.0.
		let w10, w20, w30, earth0, perihelion0: Double
		/// The mean motions ν of W1 and n′ of T, and the constants Γ, E, and e′.
		let w11, gamma, e, earth1, eccentricity: Double
		/// The mean motions of W2 and W3 and the coefficient of T² in W1.
		let w21, w31, w12: Double
		/// The corrections to the secular terms of the lunar angles that follow DE405, or `nil`.
		let secular: SecularCorrections?
	}

	/// The corrections to the coefficients of T³ and T⁴ in W1, T² and T³ in W2, and T² and T³
	/// in W3, in arcseconds per century to the power of the term.
	struct SecularCorrections: Sendable {
		let w13, w14, w22, w23, w32, w33: Double
	}
}

extension ELPMPP02 {
	/// Returns the Moon's geocentric position and velocity from the series, in the frame and
	/// units of `ELPMPP02.for`.
	///
	/// - Parameters:
	///   - days: TDB in days from J2000.0.
	///   - series: The series of a fit.
	/// - Returns: The position, in kilometers, and velocity, in kilometers per day, in the fit's
	///   inertial mean ecliptic and equinox of J2000.0.
	static func seriesState(at days: Double, series: Series) -> (position: Vector3, velocity: Vector3) {
		series.state(at: days / daysPerCentury)
	}

	/// Returns the Moon's geocentric position and velocity in a fit's ecliptic.
	///
	/// - Parameters:
	///   - tdb: A Julian Date in TDB.
	///   - series: The series of a fit.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside the coverage.
	static func eclipticState(at tdb: JulianDate, series: Series) -> (position: Vector3, velocity: Vector3)? {
		guard builtInEphemerisCoverage.contains(tdb) else { return nil }
		let state = seriesState(at: tdb.daysSinceJ2000, series: series)
		let scale = 1 / Distance.kilometersPerAstronomicalUnit
		return (state.position * scale, state.velocity * scale)
	}

	/// Returns the Moon's geocentric position and velocity in the ICRS.
	///
	/// - Parameters:
	///   - tdb: A Julian Date in TDB.
	///   - fit: The fit of the solution's constants.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside the coverage.
	static func state<F: Fit>(at tdb: JulianDate, fit: F.Type) -> (position: Vector3, velocity: Vector3)? {
		guard let ecliptic = eclipticState(at: tdb, series: F.series) else { return nil }
		let rotation = F.Ecliptic.rotation(to: ICRS.self)
		return (rotation.apply(to: ecliptic.position), rotation.apply(to: ecliptic.velocity))
	}
}
