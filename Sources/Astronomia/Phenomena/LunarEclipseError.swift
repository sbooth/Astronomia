//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding eclipses of the Moon, or their local circumstances.
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
	/// The observer is at the center of the Earth, which has no horizon.
	case noHorizon
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

extension LunarEclipseError {
	/// Creates the error for a failure finding risings and settings.
	init(_ error: RiseTransitSetError) {
		switch error {
		case .noHorizon: self = .noHorizon
		case .invalidInterval: self = .invalidInterval
		case let .timescaleConversion(error): self = .timescaleConversion(error)
		case let .ephemeris(error): self = .ephemeris(error)
		// Only a star's place fails with a star error, and only a search for the next event
		// fails to find one; the risings and settings of an eclipse are found in an interval.
		case .star, .eventNotFound: self = .ephemeris(.invalidState)
		}
	}
}
