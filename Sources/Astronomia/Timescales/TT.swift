//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Terrestrial Time (TT).
///
/// TT is the time coordinate of a clock on the geoid, and the hub through which all
/// conversions in this library pass.
///
/// This library realizes TT as TT(TAI) = TAI + 32.184 s. TT(BIPM), computed retrospectively
/// from the ensemble of primary frequency standards, currently differs from TT(TAI) by a few
/// tens of microseconds.
///
/// - Note: For dates before TAI existed (1958), TT is still well defined, but reaching it
///   from a civil time requires a model of ΔT = TT - UT1 rather than TAI.
public enum TT: Timescale {
	public static let abbreviation = "TT"

	/// TT - TAI, in seconds.
	public static let offsetFromTAI: Double = 32.184

	/// TT - TAI as an interval.
	static let intervalFromTAI = DayInterval(uncheckedDays: 0, fractionalDay: offsetFromTAI / secondsPerDay)

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		julianDate
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		julianDate
	}
}
