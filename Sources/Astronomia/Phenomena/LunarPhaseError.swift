//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when naming a phase of the Moon.
public enum LunarPhaseError: Error, Hashable, Sendable {
	/// The excess of the ecliptic longitude is NaN or infinite.
	case nonFiniteValue
	/// The half-width of a principal phase is NaN, infinite, or outside the closed interval
	/// [0°, 45°].
	case invalidHalfWidth
}
