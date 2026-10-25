//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding the Moon's passages through its nodes.
public enum LunarNodeError: Error, Hashable, Sendable {
	/// The interval ends before it starts.
	case invalidInterval
	/// The interval can't be converted to TT.
	case timescaleConversion(TimescaleConversionError)
	/// The ephemeris failed for an instant in the interval.
	case ephemeris(EphemerisError)
	/// The passage wasn't found within a draconic month after the instant, as for an ephemeris
	/// whose Moon doesn't move as the Moon does.
	case nodeNotFound
}

extension LunarNodeError {
	/// Creates the error for a failure of an interval.
	init(_ failure: SearchInterval.Failure) {
		switch failure {
		case .invalidInterval: self = .invalidInterval
		case let .timescaleConversion(error): self = .timescaleConversion(error)
		}
	}
}
