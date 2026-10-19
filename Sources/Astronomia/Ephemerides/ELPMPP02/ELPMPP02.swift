//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The ELP/MPP02 lunar solution (Chapront and Francou 2003).
///
/// The solution gives the geocentric longitude, latitude, and distance of the Moon as series in
/// TDB, whose arguments are polynomials in time. The constants of the solution are fitted either
/// to lunar laser ranging or to the DE405 ephemeris. The built-in series are truncated for
/// J1000.0 to J3000.0 so that the error from truncation is near 0.2 mas in direction and 10 m in
/// distance, well below the solution's own error.
///
/// - Note: Chapront, J., Francou, G. (2003). The lunar theory ELP revisited. Introduction of new
///   planetary perturbations. Astronomy & Astrophysics 404, 735.
enum ELPMPP02 {
	/// The fit of the solution's constants.
	enum Fit: Sendable {
		/// Lunar laser ranging from 1970 to 2001, the solution's default.
		case laserRanging
		/// The DE405 ephemeris from 1950 to 2060, with corrections to the secular terms of the
		/// lunar angles that follow DE405 over several thousand years.
		case de405
	}

	/// The inertial mean ecliptic and equinox of J2000.0 as realized by ELP/MPP02.
	enum Ecliptic: EclipticFrame, FixedReferenceFrame {
		static let name = "ELP/MPP02 ecliptic J2000"

		static let rotationFromICRS = rotationToICRS.inverse
	}

	/// The rotation from the solution's ecliptic to the ICRS, R3(-φ) R1(-ε), with
	/// ε = 23° 26′ 21.41045″ and φ = -0.05242″.
	///
	/// The angles are fitted to DE421 from 1950 to 2050, together with each fit's
	/// ``Fit/longitudeOffset``. They are within 1 mas and 3 mas of those Chapront et al. (2002)
	/// find for the ICRS, ε = 23° 26′ 21.41100″ and φ = -0.05542″, from an earlier solution.
	static let rotationToICRS = Rotation<Ecliptic, ICRS>.aboutZ(.arcseconds(0.052_42))
		* Rotation<Ecliptic, Ecliptic>.aboutX(.arcseconds(-84_381.410_45))

	/// The TDB dates of the built-in series, J1000.0 to J3000.0.
	static let coverage = JulianDate(uncheckedJulianDayNumber: 2_086_295, fractionFromNoon: 0)
		... JulianDate(uncheckedJulianDayNumber: 2_816_795, fractionFromNoon: 0)

	/// Julian days per Julian century, the unit of time of the series.
	static let daysPerCentury: Double = 36_525
}

extension ELPMPP02.Fit {
	/// The offset of the fit's origin of longitudes from the x axis of ``ELPMPP02/Ecliptic``,
	/// fitted to DE421.
	///
	/// The two fits differ mainly by their origin of longitudes at J2000.0, by about 0.036″, as
	/// Chapront and Francou (2003) note.
	var longitudeOffset: Angle {
		switch self {
		case .laserRanging: .arcseconds(0.039_41)
		case .de405: .arcseconds(0.004_24)
		}
	}

	/// The solution for this fit.
	var solution: ELPMPP02.Solution {
		switch self {
		case .laserRanging: ELPMPP02.Solution.laserRanging
		case .de405: ELPMPP02.Solution.de405
		}
	}
}

extension ELPMPP02 {
	/// Returns the Moon's geocentric position and velocity from the series, in the frame and
	/// units of `ELPMPP02.for`.
	///
	/// - Parameters:
	///   - days: TDB in days from J2000.0.
	///   - fit: The fit of the solution's constants.
	/// - Returns: The position, in kilometers, and velocity, in kilometers per day, in the fit's
	///   inertial mean ecliptic and equinox of J2000.0.
	static func seriesState(at days: Double, fit: Fit) -> (position: Vector3, velocity: Vector3) {
		fit.solution.state(at: days / daysPerCentury)
	}

	/// Returns the Moon's geocentric position and velocity in the solution's ecliptic.
	///
	/// - Parameters:
	///   - tdb: A Julian Date in TDB.
	///   - fit: The fit of the solution's constants.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside ``coverage``.
	static func eclipticState(at tdb: JulianDate, fit: Fit) -> (position: Vector3, velocity: Vector3)? {
		guard coverage.contains(tdb) else { return nil }
		let state = seriesState(at: tdb.daysSinceJ2000, fit: fit)
		let offset = Rotation<Ecliptic, Ecliptic>.aboutZ(-fit.longitudeOffset)
		let scale = 1 / Distance.kilometersPerAstronomicalUnit
		return (offset.apply(to: state.position) * scale, offset.apply(to: state.velocity) * scale)
	}

	/// Returns the Moon's geocentric position and velocity in the ICRS.
	///
	/// - Parameters:
	///   - tdb: A Julian Date in TDB.
	///   - fit: The fit of the solution's constants.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside ``coverage``.
	static func state(at tdb: JulianDate, fit: Fit) -> (position: Vector3, velocity: Vector3)? {
		guard let ecliptic = eclipticState(at: tdb, fit: fit) else { return nil }
		return (rotationToICRS.apply(to: ecliptic.position), rotationToICRS.apply(to: ecliptic.velocity))
	}
}
