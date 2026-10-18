//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating or computing calendar dates.
public enum CalendarError: Error, Hashable, Sendable {
	/// A number of days cannot be represented as an `Int`.
	case dayCountNotRepresentable
	/// The date components do not form a valid date, such as February 30, month 13, or day of
	/// year 400.
	case invalidDate
	/// The day fraction is outside the right-open interval [0, 1).
	case invalidDayFraction
	/// The number of years in the decimal year cannot be represented as an `Int`.
	case invalidDecimalYear
	/// The hour, minute, or second is outside its range.
	case invalidTimeOfDay
	/// A date's Julian day number cannot be represented as a ``JulianDayNumber``.
	case julianDayNumberNotRepresentable
	/// The day fraction or number of days is not finite.
	case nonFiniteValue
}

extension CalendarError {
	/// Creates a calendar error from the time of day error that caused it.
	init(_ error: TimeOfDayError) {
		switch error {
		case .invalid:
			self = .invalidTimeOfDay
		case .nonFiniteValue:
			self = .nonFiniteValue
		}
	}
}
