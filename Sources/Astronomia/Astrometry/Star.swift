//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A star, or any other source outside the solar system, given by its catalog astrometry: its
/// place in the ICRS at a catalog epoch, its proper motion, parallax, and radial velocity.
///
/// The values are those of catalogs such as Gaia and Hipparcos: the barycentric direction at
/// the epoch, the proper motion in right ascension multiplied by the cosine of the
/// declination, and the observed radial velocity. The star moves in a straight line at
/// constant speed, as in `eraStarpm` of ERFA, which includes the foreshortening of its motion
/// toward or away from the Sun and the change in the light time as it moves.
///
/// ```swift
/// let barnard = try Star(
/// 	rightAscension: .degrees(269.452_075_11),
/// 	declination: .degrees(4.693_390_88),
/// 	properMotionInRightAscension: .milliarcseconds(-801.551),
/// 	properMotionInDeclination: .milliarcseconds(10_362.394),
/// 	parallax: .milliarcseconds(548.31),
/// 	radialVelocity: .kilometersPerSecond(-110.51),
/// 	epoch: Instant(JulianDate(julianEpoch: 1991.25)))
/// let place = try Observer.geocenter.observation(at: instant).apparentPlace(of: barnard)
/// ```
///
/// A star without a parallax, as a quasar, is observed without parallax, at a nominal distance
/// of 1 Gpc as in Skyfield. Its motion still needs a distance: as `eraPmsafe` of ERFA does,
/// the motion of a star without a parallax, or with one so small that its proper motion would
/// mean a transverse speed of more than about 1% of the speed of light, is taken at the
/// distance where its transverse speed is that, or at 1 Gpc if that is closer. Its place is
/// then the direction from the barycenter when the light passes the observer, shifted by the
/// catalog's parallax, if any, as `eraPmpx` of ERFA does.
///
/// A star is moved in a straight line for at most 10 million Julian years from its epoch,
/// and is a star only while it is at least about 20,600 au from the solar system barycenter,
/// the distance of the greatest parallax. ``propagated(to:)`` and the places of an
/// ``Observation`` throw a ``StarError`` beyond either limit.
///
/// - Note: Gaia's epochs are in TCB, which differs from TDB by about 20 s in 2016. The
///   difference moves a star by under 1 µas and can be ignored.
public struct Star: Hashable, Sendable {
	/// The right ascension in the ICRS at the epoch.
	public let rightAscension: Angle
	/// The declination in the ICRS at the epoch.
	public let declination: Angle
	/// The proper motion in right ascension per Julian year, multiplied by the cosine of the
	/// declination.
	public let properMotionInRightAscension: Angle
	/// The proper motion in declination per Julian year.
	public let properMotionInDeclination: Angle
	/// The parallax, or `nil` if it is unknown or the source is too distant to have one.
	public let parallax: Angle?
	/// The radial velocity, positive away from the solar system barycenter.
	public let radialVelocity: Speed
	/// The epoch of the catalog values.
	public let epoch: Instant<TDB>

	/// Creates a star from its catalog astrometry.
	///
	/// - Parameters:
	///   - rightAscension: The right ascension in the ICRS at the epoch.
	///   - declination: The declination in the ICRS at the epoch.
	///   - properMotionInRightAscension: The proper motion in right ascension per Julian year,
	///     multiplied by the cosine of the declination.
	///   - properMotionInDeclination: The proper motion in declination per Julian year.
	///   - parallax: The parallax, or `nil` if it is unknown or the source is too distant to
	///     have one.
	///   - radialVelocity: The radial velocity, positive away from the solar system
	///     barycenter.
	///   - epoch: The epoch of the catalog values.
	/// - Throws:
	///   - ``StarError/nonFiniteValue`` if any value is NaN or infinite.
	///   - ``StarError/invalidDeclination`` if the declination is outside the
	///     closed interval [-90°, 90°].
	///   - ``StarError/invalidParallax`` if the parallax is negative, or greater than 10",
	///     which would put the source within about 20,600 au of the Sun. The nearest star's is
	///     0.77".
	///   - ``StarError/excessiveRadialVelocity`` if the radial velocity is half the speed of
	///     light or more.
	public init(
		rightAscension: Angle,
		declination: Angle,
		properMotionInRightAscension: Angle = .zero,
		properMotionInDeclination: Angle = .zero,
		parallax: Angle? = nil,
		radialVelocity: Speed = .zero,
		epoch: Instant<TDB>
	) throws(StarError) {
		let values = [rightAscension.radians, declination.radians, properMotionInRightAscension.radians, properMotionInDeclination.radians, parallax?.radians ?? 0, radialVelocity.astronomicalUnitsPerDay]
		guard values.allSatisfy(\.isFinite) else { throw .nonFiniteValue }
		guard abs(declination.radians) <= halfPi else { throw .invalidDeclination }
		if let parallax, parallax.radians < 0 || parallax.radians > Self.maximumParallax.radians { throw .invalidParallax }
		guard abs(radialVelocity.astronomicalUnitsPerDay) < Self.maximumSpeed else { throw .excessiveRadialVelocity }
		self.init(uncheckedRightAscension: rightAscension, declination: declination, properMotionInRightAscension: properMotionInRightAscension, properMotionInDeclination: properMotionInDeclination, parallax: parallax, radialVelocity: radialVelocity, epoch: epoch)
	}

	/// Creates a star from values already known to be valid.
	///
	/// - Precondition: The values satisfy the requirements of the public initializer.
	init(
		uncheckedRightAscension rightAscension: Angle,
		declination: Angle,
		properMotionInRightAscension: Angle,
		properMotionInDeclination: Angle,
		parallax: Angle?,
		radialVelocity: Speed,
		epoch: Instant<TDB>
	) {
		assert([rightAscension.radians, declination.radians, properMotionInRightAscension.radians, properMotionInDeclination.radians, parallax?.radians ?? 0, radialVelocity.astronomicalUnitsPerDay].allSatisfy(\.isFinite), "Non-finite value")
		assert(abs(declination.radians) <= halfPi, "Declination must be in the closed interval [-π/2, π/2]")
		assert((parallax?.radians ?? 0) >= 0 && (parallax?.radians ?? 0) <= Self.maximumParallax.radians, "Parallax must be in the closed interval [0, 10″]")
		assert(abs(radialVelocity.astronomicalUnitsPerDay) < Self.maximumSpeed, "Radial velocity must be in the open interval (-c/2, c/2)")
		self.rightAscension = rightAscension
		self.declination = declination
		self.properMotionInRightAscension = properMotionInRightAscension
		self.properMotionInDeclination = properMotionInDeclination
		self.parallax = parallax
		self.radialVelocity = radialVelocity
		self.epoch = epoch
	}

	/// The greatest span, in days, over which a star is moved from its epoch: 10 million
	/// Julian years.
	///
	/// Over longer spans a star's orbit in the galaxy departs far from a straight line. The
	/// limit also bounds the light time: a star moving at under the speed of light can be no
	/// farther than 1 Gpc plus 10 million light years.
	static let maximumTimeSpan = 10_000_000 * daysPerJulianYear

	/// The greatest parallax, of a source about 20,600 au from the Sun.
	///
	/// A source nearer than that is within the solar system, where the observer's own distance
	/// from the barycenter matters, and isn't a star.
	static let maximumParallax = Angle(arcseconds: 10)

	/// The greatest radial speed, half the speed of light, in au/day, as in `eraStarpv` of
	/// ERFA.
	static let maximumSpeed = 0.5 * speedOfLightAstronomicalUnitsPerDay
}
