//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding the rises, sets, and transits of a target.
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
	/// The event wasn't found within the limit of the search, as for a target that doesn't
	/// rise or set at the site in that time.
	case eventNotFound
}
