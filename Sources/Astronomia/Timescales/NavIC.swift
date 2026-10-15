//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// NavIC (IRNSS) Network Time (IRNWT).
///
/// IRNWT = TAI - 19 s. Its start epoch is 00:00 UT on 1999-08-22, at which IRNWT was ahead
/// of UTC by 13 leap seconds, so NavIC week 0 coincides with Galileo week 0 and GPS week 1024.
///
/// - Note: For dates before 1999-08-22 the conversion is arithmetic only.
public enum NavIC: FixedTAIOffsetTimescale {
	public static let abbreviation = "IRNWT"

	/// IRNWT - TAI, in whole seconds.
	public static let offsetFromTAI = -19

	/// The IRNWT start epoch, 1999-08-22T00:00:00 IRNWT, the same as ``Galileo/epoch``.
	public static let epoch = Galileo.epoch
}
