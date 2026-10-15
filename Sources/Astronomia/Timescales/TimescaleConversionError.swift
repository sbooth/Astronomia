//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when converting from one timescale to another.
public enum TimescaleConversionError: Error, Hashable, Sendable {
	/// The resulting Julian day number cannot be represented as a ``JulianDayNumber``.
	case dateOutOfRange
	/// No Earth orientation data covers the date, and no model was provided.
	case earthOrientationDataUnavailable
	/// The time of day is invalid.
	case invalidTimeOfDay
	/// The leap second table from IERS Bulletin C is expired.
	case leapSecondTableExpired
	/// The value is NaN or infinite.
	case nonFiniteValue
	/// The requested timescale conversion is not supported.
	case unsupported
}

extension TimescaleConversionError {
	/// Creates a timescale conversion error from the day interval error that caused it.
	init(_ error: DayIntervalError) {
		switch error {
		case .nonFiniteValue:
			self = .nonFiniteValue
		case .dayCountNotRepresentable:
			self = .dateOutOfRange
		}
	}
}

extension TimescaleConversionError {
	/// Creates a timescale conversion error from the Julian Date error that caused it.
	init(_ error: JulianDateError) {
		switch error {
		case .nonFiniteValue:
			self = .nonFiniteValue
		case .julianDayNumberNotRepresentable:
			self = .dateOutOfRange
		}
	}
}
