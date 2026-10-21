//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating a star.
public enum StarError: Error, Hashable, Sendable {
	/// A coordinate, proper motion, parallax, or radial velocity is NaN or infinite.
	case nonFiniteValue
	/// The declination is outside the closed interval [-90°, 90°].
	case invalidDeclination
	/// The parallax is negative.
	case negativeParallax
	/// The radial velocity is half the speed of light or more.
	case excessiveRadialVelocity
}
