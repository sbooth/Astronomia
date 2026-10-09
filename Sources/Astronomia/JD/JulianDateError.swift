//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating or computing Julian Dates.
public enum JulianDateError: Error, Hashable, Sendable {
	/// A value is NaN or infinite.
	case nonFiniteValue
	/// The resulting Julian day number is not representable as a ``JulianDayNumber``.
	case julianDayNumberNotRepresentable
	/// A number of days cannot be represented as an `Int`.
	case dayCountNotRepresentable
}
