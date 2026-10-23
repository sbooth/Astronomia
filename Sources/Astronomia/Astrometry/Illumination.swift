//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// How a body is lit by the Sun as an observer sees it: its phase angle and illuminated
/// fraction, its elongation from the Sun, and the direction of its bright limb.
///
/// The phase angle is the angle at the body between the Sun and the observer, from the
/// body's place corrected for light time and the Sun's place when the light that reflects
/// toward the observer left it. The body, taken as a sphere, shows the observer an illuminated
/// fraction (1 + cos i) / 2 of its disk: 1 at a phase angle of 0°, as for a full Moon, and 0 at
/// 180°, as for a new Moon.
///
/// The elongation and the bright limb are measured on the sky, between the apparent places of
/// the body and the Sun. The bright limb faces the Sun, so its position angle is the Sun's
/// from the body, measured from the north point of the body's disk through east, in the true
/// equator and equinox of date, as in Meeus, Astronomical Algorithms, Chapter 48.
///
/// ```swift
/// let sky = try Observer.geocenter.observation(at: instant)
/// let moon = try sky.illumination(of: .moon)
/// print(moon.illuminatedFraction, moon.phaseAngle.degrees)
/// ```
///
/// From a site on the Earth the Moon's parallax, up to about 1°, changes its phase angle by
/// as much, and so its illuminated fraction by up to about 0.009.
public struct Illumination: Hashable, Sendable {
	/// The angle at the body between the Sun and the observer, in [0°, 180°].
	public let phaseAngle: Angle
	/// The illuminated fraction of the body's disk, in [0, 1].
	public let illuminatedFraction: Double
	/// The angle between the body and the Sun seen by the observer, in [0°, 180°].
	public let elongation: Angle
	/// The position angle of the midpoint of the bright limb, measured from the north point of
	/// the body's disk through east, in the true equator and equinox of date, in [0°, 360°).
	public let brightLimbPositionAngle: Angle
	/// The instant of observation.
	public let instant: Instant<TT>

	/// Creates an illumination from its phase angle, elongation, and bright limb.
	init(phaseAngle: Angle, elongation: Angle, brightLimbPositionAngle: Angle, instant: Instant<TT>) {
		self.phaseAngle = phaseAngle
		self.illuminatedFraction = (1 + Math.cos(phaseAngle.radians)) / 2
		self.elongation = elongation
		self.brightLimbPositionAngle = brightLimbPositionAngle
		self.instant = instant
	}
}
