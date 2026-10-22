//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating an observer.
public enum ObserverError: Error, Hashable, Sendable {
	/// A coordinate is NaN or infinite.
	case nonFiniteValue
	/// The latitude is outside the closed interval [-90°, 90°].
	case invalidLatitude
	/// The height is more than 100 km above or below the ellipsoid.
	case invalidHeight
}
