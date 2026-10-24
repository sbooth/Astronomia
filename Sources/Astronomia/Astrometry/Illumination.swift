//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// How a body is lit by the Sun as an observer sees it: its phase angle and illuminated
/// fraction, its elongation east or west of the Sun, the excess of its ecliptic longitude over
/// the Sun's, and the direction of its bright limb.
///
/// The phase angle is the angle at the body between the Sun and the observer, from the
/// body's place corrected for light time and the Sun's place when the light that reflects
/// toward the observer left it. The body, taken as a sphere, shows the observer an illuminated
/// fraction (1 + cos i) / 2 of its disk: 1 at a phase angle of 0°, as for a full Moon, and 0 at
/// 180°, as for a new Moon.
///
/// The elongation and the bright limb are measured on the sky, between the apparent places of
/// the body and the Sun. The elongation is the angle between them, as the Explanatory
/// Supplement to the Astronomical Almanac defines it, east of the Sun when the body's
/// ecliptic longitude exceeds the Sun's by less than 180°, as for a waxing Moon or Venus as an
/// evening star, and west of it otherwise. The bright limb faces the Sun, so its position
/// angle is the Sun's from the body, measured from the north point of the body's disk through
/// east, in the true equator and equinox of date, as in Meeus, Astronomical Algorithms,
/// Chapter 48. From a site, the bright limb is also measured from the top of the disk as the
/// site sees it, turned from the north point by the body's parallactic angle.
///
/// The excess of the body's apparent ecliptic longitude over the Sun's, by which the
/// Astronomical Almanac defines the phases of the Moon, grows steadily through each lunation,
/// through 180° at full Moon whatever the Moon's latitude, so ``moonPhaseName`` names the Moon's
/// phase from it. It differs from the elongation, an angle on the sky, by up to about the
/// Moon's latitude, 5°.
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
	/// The angle at the body between the Sun and the observer, in the closed interval
	/// [0, 180]°.
	public let phaseAngle: Angle
	/// The illuminated fraction of the body's disk, in the closed interval [0, 1].
	public let illuminatedFraction: Double
	/// The angle between the body and the Sun seen by the observer, in the closed interval
	/// [0, 180]°.
	public let elongation: Angle
	/// The excess of the body's apparent ecliptic longitude over the Sun's, in the true ecliptic
	/// and equinox of date, in the right-open interval [0, 360)°.
	public let excessEclipticLongitude: Angle
	/// Whether the body is east of the Sun: whether its apparent ecliptic longitude exceeds the
	/// Sun's by an angle in the open interval (0, 180)°.
	public var isEastOfSun: Bool {
		excessEclipticLongitude.radians > 0 && excessEclipticLongitude.radians < .pi
	}
	/// The position angle of the midpoint of the bright limb, measured from the north point of
	/// the body's disk through east, in the true equator and equinox of date, in the right-open
	/// interval [0, 360)°.
	public let brightLimbPositionAngle: Angle
	/// The position angle of the midpoint of the bright limb measured from the top of the
	/// body's disk as a site sees it, the zenith side, in the same sense as
	/// ``brightLimbPositionAngle``, in the right-open interval [0, 360)°, or `nil` for an
	/// observer at the center of the Earth, which has no zenith.
	///
	/// It is the Sun's position angle from the body measured from the zenith's direction on
	/// the sky at the body, the normal to the site's ellipsoid, and is nearly
	/// ``brightLimbPositionAngle`` less the body's ``ObservedPlace/parallacticAngle``, as Meeus
	/// gives it. Nearly, because the two are measured from different poles: the position angle
	/// from the true pole of date, and the parallactic angle from the pole of the ITRS, which
	/// is the true pole moved by the polar motion, up to about 0.5". Their difference can differ
	/// from this angle by the polar motion's turn of the north point at the body, about that
	/// much, and more near the poles. Refraction, which raises the body's lower limb more than
	/// its upper, flattens the disk near the horizon but doesn't turn it. At the zenith, where
	/// the zenith has no direction on the sky, the angle is taken from a direction of 0.
	public let brightLimbZenithAngle: Angle?
	/// The instant of observation.
	public let instant: Instant<TT>

	/// Creates an illumination from its phase angle, elongation, excess of longitude, and bright
	/// limb.
	///
	/// - Parameters:
	///   - phaseAngle: The phase angle, in the closed interval [0, 180]°.
	///   - elongation: The elongation, in the closed interval [0, 180]°.
	///   - excessEclipticLongitude: The excess of the body's ecliptic longitude over the Sun's,
	///     in the right-open interval [0, 360)°.
	///   - brightLimbPositionAngle: The position angle of the bright limb, in the right-open
	///     interval [0, 360)°.
	///   - brightLimbZenithAngle: The bright limb's angle from the zenith, in the right-open
	///     interval [0, 360)°, or `nil` from the center of the Earth.
	///   - instant: The instant of observation.
	init(phaseAngle: Angle, elongation: Angle, excessEclipticLongitude: Angle, brightLimbPositionAngle: Angle, brightLimbZenithAngle: Angle?, instant: Instant<TT>) {
		assert(phaseAngle.radians >= 0 && phaseAngle.radians <= .pi, "Phase angle must be in the closed interval [0, 180]°")
		assert(elongation.radians >= 0 && elongation.radians <= .pi, "Elongation must be in the closed interval [0, 180]°")
		assert(excessEclipticLongitude.radians >= 0 && excessEclipticLongitude.radians < twoPi, "Excess ecliptic longitude must be in the right-open interval [0, 360)°")
		assert(brightLimbPositionAngle.radians >= 0 && brightLimbPositionAngle.radians < twoPi, "Position angle of the bright limb must be in the right-open interval [0, 360)°")
		assert(brightLimbZenithAngle.map { $0.radians >= 0 && $0.radians < twoPi } ?? true, "Bright limb's angle from the zenith must be in the right-open interval [0, 360)°")
		self.phaseAngle = phaseAngle
		self.illuminatedFraction = (1 + Math.cos(phaseAngle.radians)) / 2
		self.elongation = elongation
		self.excessEclipticLongitude = excessEclipticLongitude
		self.brightLimbPositionAngle = brightLimbPositionAngle
		self.brightLimbZenithAngle = brightLimbZenithAngle
		self.instant = instant
	}
}

extension Illumination {
	/// The phase of the Moon this illumination names, with a principal phase within 5° of the
	/// excess of the ecliptic longitude at it, about 10 hours.
	public var moonPhaseName: MoonPhaseName {
		MoonPhaseName(uncheckedExcessEclipticLongitude: excessEclipticLongitude)
	}

	/// Returns the phase of the Moon this illumination names.
	///
	/// - Parameter principalHalfWidth: The half-width of a principal phase, in excess of the
	///   ecliptic longitude, in the closed interval [0, 45]°.
	/// - Returns: The phase.
	/// - Throws: ``MoonPhaseNameError/invalidHalfWidth`` if `principalHalfWidth` is NaN, infinite,
	///   or outside the closed interval [0, 45]°.
	public func moonPhaseName(principalHalfWidth: Angle) throws(MoonPhaseNameError) -> MoonPhaseName {
		try MoonPhaseName(excessEclipticLongitude: excessEclipticLongitude, principalHalfWidth: principalHalfWidth)
	}
}
