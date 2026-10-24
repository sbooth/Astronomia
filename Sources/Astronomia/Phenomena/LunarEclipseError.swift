//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding eclipses of the Moon.
public enum LunarEclipseError: Error, Hashable, Sendable {
	/// The interval ends before it starts, or an instant of the search can't be represented.
	case invalidInterval
	/// The interval can't be converted to TT.
	case timescaleConversion(TimescaleConversionError)
	/// The ephemeris failed for an instant of the search.
	case ephemeris(EphemerisError)
	/// No eclipse was found within the search's span after the instant, as for an ephemeris
	/// whose Moon doesn't move as the Moon does.
	case eclipseNotFound
}

extension LunarEclipseError {
	/// Creates the error for a failure finding the phases of the Moon.
	init(_ error: MoonPhaseError) {
		switch error {
		case .invalidInterval, .phaseNotFound: self = .invalidInterval
		case let .timescaleConversion(error): self = .timescaleConversion(error)
		case let .ephemeris(error): self = .ephemeris(error)
		}
	}
}
