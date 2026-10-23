//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding the phases of the Moon.
public enum MoonPhaseError: Error, Hashable, Sendable {
	/// The interval ends before it starts.
	case invalidInterval
	/// The interval can't be converted to TT.
	case timescaleConversion(TimescaleConversionError)
	/// The ephemeris failed for an instant in the interval.
	case ephemeris(EphemerisError)
}

extension MoonPhaseError {
	/// Creates the error for a failure of an interval.
	init(_ failure: SearchInterval.Failure) {
		switch failure {
		case .invalidInterval: self = .invalidInterval
		case let .timescaleConversion(error): self = .timescaleConversion(error)
		}
	}
}
