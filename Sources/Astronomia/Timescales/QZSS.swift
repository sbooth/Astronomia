//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// QZSS Time (QZSST).
///
/// QZSST = TAI - 19 s. QZSS is aligned with GPS and shares its week numbering, so QZSST
/// differs from ``GPS`` only by the small steering offset broadcast by the satellites.
public enum QZSS: FixedTAIOffsetTimescale {
	public static let abbreviation = "QZSST"

	/// QZSST - TAI, in whole seconds.
	public static let offsetFromTAI = -19

	/// The QZSST epoch, the same as ``GPS/epoch``.
	public static let epoch = GPS.epoch
}
