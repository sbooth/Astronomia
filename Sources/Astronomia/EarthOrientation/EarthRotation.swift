//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Earth's rotation: the Earth rotation angle and Greenwich mean sidereal time.
///
/// The Earth rotation angle (ERA) is the angle between the celestial and terrestrial
/// intermediate origins, measured along the equator of the celestial intermediate pole. It is
/// a linear function of UT1 (IAU 2000 Resolution B1.8), and with polar motion and the
/// precession-nutation of the pole it orients Earth in space.
///
/// Greenwich mean sidereal time (GMST) is the hour angle of the mean equinox at Greenwich. In
/// the IAU 2006 model it is the ERA plus the accumulated precession in right ascension, a
/// polynomial in TT, so it needs both UT1 and TT for the same instant.
///
/// Greenwich apparent sidereal time also needs the equation of the equinoxes, from nutation,
/// so it is not provided here. For a local sidereal time, add the east longitude.
///
/// Instants in other timescales convert first: for example,
/// `try EarthRotation.angle(at: utc.converted(to: UT1.self))`.
public enum EarthRotation {
	/// Returns the Earth rotation angle at the specified UT1 instant.
	///
	/// - Parameter ut1: An instant in UT1.
	/// - Returns: The Earth rotation angle, in the right-open interval [0, 2π).
	public static func angle(at ut1: Instant<UT1>) -> Angle {
		earthRotationAngle(ut1: ut1.julianDate)
	}

	/// Returns Greenwich mean sidereal time at the specified UT1 instant, from the IAU 2006
	/// model.
	///
	/// - Parameters:
	///   - ut1: An instant in UT1.
	///   - context: The source of ΔT used to find TT.
	/// - Returns: Greenwich mean sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if TT cannot be found.
	public static func greenwichMeanSiderealTime(at ut1: Instant<UT1>, context: UT1.Context = UT1.defaultContext) throws(TimescaleConversionError) -> Angle {
		let tt = try UT1.toTT(ut1.julianDate, context: context)
		return greenwichMeanSiderealTime(ut1: ut1.julianDate, tt: tt)
	}

	/// Returns Greenwich mean sidereal time at the specified TT instant, from the IAU 2006
	/// model.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - ut1Context: The source of ΔT used to find UT1.
	/// - Returns: Greenwich mean sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public static func greenwichMeanSiderealTime(at tt: Instant<TT>, ut1Context: UT1.Context = UT1.defaultContext) throws(TimescaleConversionError) -> Angle {
		let ut1 = try UT1.fromTT(tt.julianDate, context: ut1Context)
		return greenwichMeanSiderealTime(ut1: ut1, tt: tt.julianDate)
	}
}

extension EarthRotation {
	/// The Earth rotation angle at J2000.0 UT1, in turns.
	static let angleAtJ2000: Double = 0.779_057_273_264_0
	/// The Earth rotation angle gained per UT1 day beyond a whole turn, in turns.
	///
	/// Earth turns 1.00273781191135448 times per UT1 day.
	static let excessTurnsPerDay: Double = 0.002_737_811_911_354_48

	/// Returns the Earth rotation angle at a UT1 Julian Date (IAU 2000 Resolution B1.8).
	///
	/// θ = 2π (0.7790572732640 + 1.00273781191135448 D_U), where D_U is UT1 days since
	/// J2000.0. The whole days of D_U are whole turns, so only the fraction of the day and the
	/// excess rotation are summed. This keeps the precision of the Julian Date's parts.
	///
	/// - Parameter ut1: A Julian Date in UT1.
	/// - Returns: The Earth rotation angle, in the right-open interval [0, 2π).
	static func earthRotationAngle(ut1: JulianDate) -> Angle {
		let days = differenceAsDouble(ut1.julianDayNumber, JulianDate.J2000.julianDayNumber) + ut1.fractionFromNoon
		let turns = ut1.fractionFromNoon + angleAtJ2000 + excessTurnsPerDay * days
		let fraction = turns - turns.rounded(.down)
		return Angle(radians: fraction * Angle.radiansPerTurn).normalized()
	}

	/// Returns Greenwich mean sidereal time from the IAU 2006 model (Capitaine et al. 2003).
	///
	/// ```
	/// GMST = ERA + 0.014506″ + 4612.156534″ t + 1.3915817″ t^2 - 0.00000044″ t^3
	///            - 0.000029956″ t^4 - 0.0000000368″ t^5
	/// ```
	///
	/// where t is TT Julian centuries since J2000.0.
	///
	/// - Parameters:
	///   - ut1: A Julian Date in UT1.
	///   - tt: The same instant as a Julian Date in TT.
	/// - Returns: Greenwich mean sidereal time, in the right-open interval [0, 2π).
	static func greenwichMeanSiderealTime(ut1: JulianDate, tt: JulianDate) -> Angle {
		let t = (differenceAsDouble(tt.julianDayNumber, JulianDate.J2000.julianDayNumber) + tt.fractionFromNoon) / 36_525
		let arcseconds = 0.014_506 + (4_612.156_534 + (1.391_581_7 + (-0.000_000_44 + (-0.000_029_956 + -0.000_000_036_8 * t) * t) * t) * t) * t
		return (earthRotationAngle(ut1: ut1) + Angle(arcseconds: arcseconds)).normalized()
	}
}
