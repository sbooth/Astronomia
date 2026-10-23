//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding equinoxes and solstices.
public enum SeasonError: Error, Hashable, Sendable {
	/// The interval ends before it starts.
	case invalidInterval
	/// The year can't be represented in the calendar.
	case invalidYear
	/// The interval can't be converted to TT.
	case timescaleConversion(TimescaleConversionError)
	/// The ephemeris failed for an instant in the interval.
	case ephemeris(EphemerisError)
}
