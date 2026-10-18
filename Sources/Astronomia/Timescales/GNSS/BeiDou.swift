//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// BeiDou Time (BDT).
///
/// BDT = TAI - 33 s = GPS - 14 s. BDT equals UTC as of its epoch, 2006-01-01, and does not
/// include later leap seconds.
///
/// - Note: For dates before 2006-01-01 the conversion is arithmetic only.
public enum BeiDou: FixedTAIOffsetTimescale {
	public static let abbreviation = "BDT"

	/// BDT - TAI, in whole seconds.
	public static let offsetFromTAI = -33

	/// The BDT epoch, 2006-01-01T00:00:00 BDT (and UTC).
	public static let epoch = JulianDate(uncheckedJulianDayNumber: 2_453_737, fractionFromNoon: -0.5)
}
