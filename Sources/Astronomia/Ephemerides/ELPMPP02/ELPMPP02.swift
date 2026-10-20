//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The lunar solution ELP/MPP02 (Chapront and Francou 2003).
///
/// The solution gives the geocentric longitude, latitude, and distance of the Moon as series in
/// TDB, whose arguments are polynomials in time. Its constants are fitted to observations, and
/// each fit, with its own realization of the ecliptic, is an ephemeris of its own:
/// ``DE405``, fitted to the DE405 ephemeris, and ``LaserRanging``, fitted to lunar laser
/// ranging. The two share the solution's series and differ in their fitted constants and their
/// frames.
///
/// ```swift
/// let moon = try ELPMPP02.de405.state(of: .moon, at: instant)
/// ```
///
/// The built-in series are truncated for J1000.0 to J3000.0 so that the error from truncation
/// is near 0.2 mas in direction and 10 m in distance, well below the solution's own error.
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

	/// The solution fitted to the DE405 ephemeris, the library's default.
	public static let de405 = DE405()

	/// The solution fitted to lunar laser ranging.
	public static let laserRanging = LaserRanging()

	/// Julian days per Julian century, the unit of time of the series.
	static let daysPerCentury: Double = 36_525
}

extension ELPMPP02 {
	/// A fit of the solution: its series with the fitted constants and its realization of the
	/// ecliptic.
	protocol Fit: Ephemeris where Body == ELPMPP02.Body, Frame == Ecliptic {
		/// The fit's realization of the inertial mean ecliptic and equinox of J2000.0.
		associatedtype Ecliptic: EclipticFrame, FixedReferenceFrame

		/// The solution's series with the fit's constants.
		static var series: Series { get }
	}

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

extension ELPMPP02.Fit {
	/// The TDB instants of the built-in series, J1000.0 to J3000.0.
	var fitCoverage: ClosedRange<Instant<TDB>> {
		Instant(builtInEphemerisCoverage.lowerBound) ... Instant(builtInEphemerisCoverage.upperBound)
	}

	/// Returns the state of the Earth or the Moon relative to the other, in the fit's ecliptic.
	func fitState(of body: ELPMPP02.Body, relativeTo origin: ELPMPP02.Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<Ecliptic> {
		guard fitCoverage.contains(tdb) else { throw .outsideCoverage }
		if body == origin {
			return .zero
		}
		guard let moon = ELPMPP02.eclipticState(at: tdb.julianDate, series: Self.series) else {
			preconditionFailure("\(tdb.julianDate) is outside the coverage of ELP/MPP02")
		}
		let state = StateVector<Ecliptic>(moon.position, moon.velocity)
		return body == .moon ? state : -state
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
	///   - fit: The fit of the solution.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside the coverage.
	static func state<F: Fit>(at tdb: JulianDate, fit: F.Type) -> (position: Vector3, velocity: Vector3)? {
		guard let ecliptic = eclipticState(at: tdb, series: F.series) else { return nil }
		let rotation = F.Ecliptic.rotation(to: ICRS.self)
		return (rotation.apply(to: ecliptic.position), rotation.apply(to: ecliptic.velocity))
	}
}
