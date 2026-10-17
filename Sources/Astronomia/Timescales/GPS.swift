//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// GPS Time.
///
/// GPS = TAI - 19 s, so GPS Time equals UTC as of its epoch, 1980-01-06, and does not
/// include later leap seconds.
///
/// - Note: For dates before 1980-01-06 the conversion is arithmetic only.
public enum GPS: FixedTAIOffsetTimescale {
	public static let abbreviation = "GPS"

	/// GPS - TAI, in whole seconds.
	public static let offsetFromTAI = -19

	/// The GPS epoch, 1980-01-06T00:00:00 GPS (and UTC).
	public static let epoch = JulianDate(uncheckedJulianDayNumber: 2_444_245, fractionFromNoon: -0.5)
}
