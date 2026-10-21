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
/// Greenwich apparent sidereal time (GAST) is the hour angle of the true equinox: the ERA less
/// the equation of the origins, the angle from the CIO to the true equinox along the equator.
/// It differs from GMST by the equation of the equinoxes, from nutation. For a local sidereal
/// time, add the east longitude.
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
	///   - earthOrientation: The source of ΔT used to find TT, in its ``EarthOrientation/ut1``.
	///     GMST does not use the celestial pole offsets.
	/// - Returns: Greenwich mean sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if TT cannot be found.
	public static func greenwichMeanSiderealTime(at ut1: Instant<UT1>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		let tt = try UT1.toTT(ut1.julianDate, context: earthOrientation.ut1)
		return greenwichMeanSiderealTime(ut1: ut1.julianDate, tt: tt)
	}

	/// Returns Greenwich mean sidereal time at the specified TT instant, from the IAU 2006
	/// model.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: The source of ΔT used to find UT1, in its
	///     ``EarthOrientation/ut1``. GMST does not use the celestial pole offsets.
	/// - Returns: Greenwich mean sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public static func greenwichMeanSiderealTime(at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		let ut1 = try UT1.fromTT(tt.julianDate, context: earthOrientation.ut1)
		return greenwichMeanSiderealTime(ut1: ut1, tt: tt.julianDate)
	}

	/// Returns Greenwich mean sidereal time at an instant in any timescale, from the IAU 2006
	/// model.
	///
	/// TT and UT1 are each converted from `instant`, so an instant already in either keeps its
	/// value.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT and UT1.
	///   - context: Observational data for converting `instant`.
	///   - earthOrientation: The source of ΔT used to find UT1.
	/// - Returns: Greenwich mean sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if TT or UT1 cannot be found.
	public static func greenwichMeanSiderealTime<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		let tt = try instant.converted(to: TT.self, sourceContext: context)
		let ut1 = try instant.converted(to: UT1.self, sourceContext: context, targetContext: earthOrientation.ut1)
		return greenwichMeanSiderealTime(ut1: ut1.julianDate, tt: tt.julianDate)
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
	/// GMST = ERA + 0.014506" + 4612.156534" t + 1.3915817" t^2 - 0.00000044" t^3
	///            - 0.000029956" t^4 - 0.0000000368" t^5
	/// ```
	///
	/// where t is TT Julian centuries since J2000.0.
	///
	/// - Parameters:
	///   - ut1: A Julian Date in UT1.
	///   - tt: The same instant as a Julian Date in TT.
	/// - Returns: Greenwich mean sidereal time, in the right-open interval [0, 2π).
	static func greenwichMeanSiderealTime(ut1: JulianDate, tt: JulianDate) -> Angle {
		(earthRotationAngle(ut1: ut1) + Angle(radians: greenwichMeanSiderealTimeLessERA(tt: tt))).normalized()
	}

	/// Returns GMST less the ERA, the accumulated precession in right ascension of the IAU 2006
	/// model (Capitaine et al. 2003).
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: The angle, in radians.
	static func greenwichMeanSiderealTimeLessERA(tt: JulianDate) -> Double {
		let t = (differenceAsDouble(tt.julianDayNumber, JulianDate.J2000.julianDayNumber) + tt.fractionFromNoon) / daysPerJulianCentury
		let arcseconds = 0.014_506 + (4_612.156_534 + (1.391_581_7 + (-0.000_000_44 + (-0.000_029_956 + -0.000_000_036_8 * t) * t) * t) * t) * t
		return arcseconds / arcsecondsPerRadian
	}
}

extension EarthRotation {
	/// Returns Greenwich apparent sidereal time at the specified UT1 instant, from the IAU
	/// 2006/2000A model.
	///
	/// GAST = ERA - EO (IERS Conventions (2010), Eq. 5.31), where the equation of the origins EO
	/// comes from the bias-precession-nutation matrix and the CIO locator s.
	///
	/// - Parameters:
	///   - ut1: An instant in UT1.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of ΔT used to
	///     find TT.
	/// - Returns: Greenwich apparent sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if TT cannot be found.
	public static func greenwichApparentSiderealTime(at ut1: Instant<UT1>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		let tt = try UT1.toTT(ut1.julianDate, context: earthOrientation.ut1)
		return greenwichApparentSiderealTime(ut1: ut1.julianDate, tt: Instant(tt), earthOrientation: earthOrientation)
	}

	/// Returns Greenwich apparent sidereal time at the specified TT instant, from the IAU
	/// 2006/2000A model.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of ΔT used to
	///     find UT1.
	/// - Returns: Greenwich apparent sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public static func greenwichApparentSiderealTime(at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		let ut1 = try UT1.fromTT(tt.julianDate, context: earthOrientation.ut1)
		return greenwichApparentSiderealTime(ut1: ut1, tt: tt, earthOrientation: earthOrientation)
	}

	/// Returns the equation of the origins, the angle from the celestial intermediate origin
	/// (CIO) to the true equinox along the equator of the CIP, measured toward the equinox's
	/// side as GAST = ERA - EO.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The equation of the origins, in the interval (-π, π].
	public static func equationOfTheOrigins(at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Angle {
		Angle(radians: IAU2006.Orientation(at: tt, earthOrientation: earthOrientation).equationOfOrigins)
	}

	/// Returns the equation of the equinoxes, GAST - GMST: the right ascension of the mean
	/// equinox measured from the true equinox.
	///
	/// It is Δψ cos ε_A plus small complementary terms. It does not depend on UT1: both
	/// sidereal times contain the same ERA.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The equation of the equinoxes, about a second of time at most.
	public static func equationOfTheEquinoxes(at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Angle {
		let equationOfOrigins = IAU2006.Orientation(at: tt, earthOrientation: earthOrientation).equationOfOrigins
		let precession = greenwichMeanSiderealTimeLessERA(tt: tt.julianDate)
		return Angle(radians: -equationOfOrigins - precession).normalizedSigned()
	}

	/// Returns Greenwich apparent sidereal time at an instant in any timescale, from the IAU
	/// 2006/2000A model.
	///
	/// TT and UT1 are each converted from `instant`, so an instant already in either keeps its
	/// value.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT and UT1.
	///   - context: Observational data for converting `instant`.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of ΔT used to
	///     find UT1.
	/// - Returns: Greenwich apparent sidereal time, in the right-open interval [0, 2π).
	/// - Throws: A ``TimescaleConversionError`` if TT or UT1 cannot be found.
	public static func greenwichApparentSiderealTime<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		let tt = try instant.converted(to: TT.self, sourceContext: context)
		let ut1 = try instant.converted(to: UT1.self, sourceContext: context, targetContext: earthOrientation.ut1)
		return greenwichApparentSiderealTime(ut1: ut1.julianDate, tt: tt, earthOrientation: earthOrientation)
	}

	/// Returns the equation of the origins at an instant in any timescale.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The equation of the origins, in the interval (-π, π].
	/// - Throws: A ``TimescaleConversionError`` if `instant` can't be converted to TT.
	public static func equationOfTheOrigins<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		equationOfTheOrigins(at: try instant.converted(to: TT.self, sourceContext: context), earthOrientation: earthOrientation)
	}

	/// Returns the equation of the equinoxes at an instant in any timescale.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The equation of the equinoxes.
	/// - Throws: A ``TimescaleConversionError`` if `instant` can't be converted to TT.
	public static func equationOfTheEquinoxes<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Angle {
		equationOfTheEquinoxes(at: try instant.converted(to: TT.self, sourceContext: context), earthOrientation: earthOrientation)
	}

	/// Returns Greenwich apparent sidereal time, ERA - EO.
	///
	/// - Parameters:
	///   - ut1: A Julian Date in UT1.
	///   - tt: The same instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: Greenwich apparent sidereal time, in the right-open interval [0, 2π).
	static func greenwichApparentSiderealTime(ut1: JulianDate, tt: Instant<TT>, earthOrientation: EarthOrientation) -> Angle {
		let equationOfOrigins = IAU2006.Orientation(at: tt, earthOrientation: earthOrientation).equationOfOrigins
		return (earthRotationAngle(ut1: ut1) - Angle(radians: equationOfOrigins)).normalized()
	}
}
