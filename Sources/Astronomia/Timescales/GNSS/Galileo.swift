//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Galileo System Time (GST).
///
/// GST = TAI - 19 s, the same as ``GPS``. Its start epoch is 1999-08-22T00:00:00 GST,
/// 13 s before UTC midnight, so Galileo week 0 coincides with GPS week 1024.
///
/// - Note: The type is named for the system rather than "GST" to avoid confusion with
///   Greenwich Sidereal Time.
/// - Note: For dates before 1999-08-22 the conversion is arithmetic only.
public enum Galileo: FixedTAIOffsetTimescale {
	public static let abbreviation = "GST"

	/// GST - TAI, in whole seconds.
	public static let offsetFromTAI = -19

	/// The GST start epoch, 1999-08-22T00:00:00 GST (1999-08-21T23:59:47 UTC).
	public static let epoch = JulianDate(uncheckedJulianDayNumber: 2_451_413, fractionFromNoon: -0.5)
}
