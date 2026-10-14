//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating or computing day intervals.
public enum DayIntervalError: Error, Hashable, Sendable {
	/// An input was NaN or infinite.
	case nonFiniteValue
	/// The whole days in the day interval cannot be represented as an `Int`.
	case dayCountNotRepresentable
}
