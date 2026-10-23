//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when finding the illumination of a body.
public enum IlluminationError: Error, Hashable, Sendable {
	/// The body is the Sun, or the observer's own body, which have no illumination as seen by
	/// the observer.
	case notIlluminated
	/// The ephemeris failed for the body or the Sun.
	case ephemeris(EphemerisError)
}
