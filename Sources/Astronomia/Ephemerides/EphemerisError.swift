//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An error from an ``Ephemeris``.
public enum EphemerisError: Error, Hashable, Sendable {
	/// The ephemeris gave a position or velocity that is NaN or infinite, a speed of light or
	/// more, or a position too far to observe.
	case invalidState
	/// The instant is outside the ephemeris's coverage.
	case outsideCoverage
	/// Converting the instant to TDB failed.
	case timescaleConversion(TimescaleConversionError)
}
