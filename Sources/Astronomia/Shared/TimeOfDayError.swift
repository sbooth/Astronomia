//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating a time of day.
public enum TimeOfDayError: Error, Hashable, Sendable {
	/// The hour, minute, or second is outside its range, or the second is 60 or more at a time
	/// other than 23:59.
	case invalid
	/// The second is NaN or infinite.
	case nonFiniteValue
}
