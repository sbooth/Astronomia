//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The altitude at which a target is taken to rise and set.
///
/// The altitude is geometric, without refraction, of the target's center or of its upper limb.
/// ``standard`` is the conventional rise and set: the upper limb at -34', the refraction
/// at the horizon in average conditions, with the semidiameter from the target's radius and
/// distance. The twilights are the Sun's center at -6°, -12°, and -18°.
///
/// ```swift
/// let sunrise = try site.riseTransitSetEvents(of: .sun, from: start, to: end)
/// let dawn = try site.riseTransitSetEvents(
/// 	of: .sun, from: start, to: end, altitude: .civilTwilight)
/// let limit = try EventAltitude.center(altitude: .degrees(15))
/// let aboveTrees = try site.riseTransitSetEvents(of: star, from: start, to: end, altitude: limit)
/// ```
///
/// - Note: Refraction at the horizon varies with the weather by several arcminutes, which moves
///   rises and sets by about a minute of time at middle latitudes, and more near the
///   poles.
public struct EventAltitude: Hashable, Sendable {
	/// The part of the target whose altitude is taken.
	enum Reference: Hashable, Sendable {
		/// The upper limb, of a target with the radius, or with the ephemeris's radius for the
		/// body if `nil`.
		case upperLimb(radius: Distance?)
		/// The center.
		case center
	}

	/// The geometric altitude of the reference.
	let altitude: Angle
	/// The part of the target whose altitude is taken.
	let reference: Reference

	/// Creates an event altitude from values already known to be valid.
	init(uncheckedAltitude altitude: Angle, reference: Reference) {
		assert(altitude.radians.isFinite && abs(altitude.radians) <= halfPi, "Altitude must be in the closed interval [-π/2, π/2]")
		self.altitude = altitude
		self.reference = reference
	}

	/// The conventional refraction at the horizon, 34'.
	static let horizonRefraction = Angle(arcminutes: 34)
}

extension EventAltitude {
	/// Conventional rise and set: the upper limb at -34', with the radius of the body from
	/// the ephemeris, or a point for a star or a body without one.
	public static let standard = EventAltitude(uncheckedAltitude: -horizonRefraction, reference: .upperLimb(radius: nil))

	/// Civil twilight: the Sun's center at -6°.
	public static let civilTwilight = EventAltitude(uncheckedAltitude: .degrees(-6), reference: .center)

	/// Nautical twilight: the Sun's center at -12°.
	public static let nauticalTwilight = EventAltitude(uncheckedAltitude: .degrees(-12), reference: .center)

	/// Astronomical twilight: the Sun's center at -18°.
	public static let astronomicalTwilight = EventAltitude(uncheckedAltitude: .degrees(-18), reference: .center)

	/// Returns the conventional rise and set of a target of a given radius: its upper limb at
	/// -34'.
	///
	/// - Parameter radius: The target's radius, which replaces the ephemeris's.
	/// - Returns: The event altitude.
	/// - Throws:
	///   - ``EventAltitudeError/nonFiniteValue`` if the radius is NaN or infinite.
	///   - ``EventAltitudeError/invalidRadius`` if the radius is negative.
	public static func standard(radius: Distance) throws(EventAltitudeError) -> EventAltitude {
		guard radius.astronomicalUnits.isFinite else {
			throw .nonFiniteValue
		}
		guard radius.astronomicalUnits >= 0 else {
			throw .invalidRadius
		}
		return EventAltitude(uncheckedAltitude: -horizonRefraction, reference: .upperLimb(radius: radius))
	}

	/// Returns the crossing of the target's center through a geometric altitude.
	///
	/// - Parameter altitude: The altitude, without refraction.
	/// - Returns: The event altitude.
	/// - Throws:
	///   - ``EventAltitudeError/nonFiniteValue`` if the altitude is NaN or infinite.
	///   - ``EventAltitudeError/invalidAltitude`` if the altitude is outside the closed
	///     interval [-90, 90]°.
	public static func center(altitude: Angle) throws(EventAltitudeError) -> EventAltitude {
		guard altitude.radians.isFinite else {
			throw .nonFiniteValue
		}
		guard abs(altitude.radians) <= halfPi else {
			throw .invalidAltitude
		}
		return EventAltitude(uncheckedAltitude: altitude, reference: .center)
	}
}
