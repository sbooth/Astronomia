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
	/// The parallax is negative, or greater than 10″, which would put the source within about
	/// 20,600 au of the Sun.
	case invalidParallax
	/// The radial velocity is half the speed of light or more.
	case excessiveRadialVelocity
	/// The instant is more than 10 million Julian years from the star's epoch, beyond which its
	/// motion in a straight line is meaningless.
	case excessiveTimeSpan
	/// At the instant, the star's motion puts it within about 20,600 au of the solar system
	/// barycenter, inside the solar system.
	case withinSolarSystem
}
