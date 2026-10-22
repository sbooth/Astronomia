//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating an observer, or finding an observed place.
public enum ObserverError: Error, Hashable, Sendable {
	/// A coordinate is NaN or infinite.
	case nonFiniteValue
	/// The latitude is outside the closed interval [-90°, 90°].
	case invalidLatitude
	/// The height is more than 100 km above or below the ellipsoid.
	case invalidHeight
	/// An observed place was requested for an observer at the center of the Earth, which has
	/// no horizon.
	case noHorizon
	/// An observed place was requested for an apparent place that can't be from the
	/// observation: one at another instant, or at the origin, as only a geocentric place of
	/// the Earth is.
	case placeMismatch
}
