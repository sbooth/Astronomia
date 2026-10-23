//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding the risings, settings, and transits of a target.
public enum RiseTransitSetError: Error, Hashable, Sendable {
	/// The observer is at the center of the Earth, which has no horizon.
	case noHorizon
	/// The interval ends before it starts.
	case invalidInterval
	/// The interval can't be converted to TT.
	case timescaleConversion(TimescaleConversionError)
	/// The ephemeris failed for a place in the interval.
	case ephemeris(EphemerisError)
	/// The star can't be observed at an instant in the interval.
	case star(StarError)
}
