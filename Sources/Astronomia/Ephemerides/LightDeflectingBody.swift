//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A body of an ephemeris whose gravity deflects light passing it, for apparent places.
///
/// Light passing a body of gravitational parameter GM at a distance d from its center turns by
/// about 4GM/(c²d): 1.75" at the Sun's limb, 16 mas at Jupiter's. No deflection is applied to
/// light whose path passes within the body's radius, as from a target behind its disk.
public struct LightDeflectingBody<Body: Hashable & Sendable>: Hashable, Sendable {
	/// The body.
	public let body: Body
	/// The gravitational parameter GM of the body, in au³/day².
	public let gravitationalParameter: Double
	/// The radius of the body.
	public let radius: Distance

	/// Creates a light-deflecting body.
	///
	/// - Parameters:
	///   - body: The body.
	///   - gravitationalParameter: The gravitational parameter GM of the body, in au³/day².
	///   - radius: The radius of the body.
	/// - Throws:
	///   - ``LightDeflectingBodyError/invalidGravitationalParameter`` if the gravitational
	///     parameter is negative, NaN, or infinite.
	///   - ``LightDeflectingBodyError/invalidRadius`` if the radius is negative, NaN, or
	///     infinite.
	public init(body: Body, gravitationalParameter: Double, radius: Distance) throws(LightDeflectingBodyError) {
		guard gravitationalParameter.isFinite, gravitationalParameter >= 0 else {
			throw .invalidGravitationalParameter
		}
		guard radius.astronomicalUnits.isFinite, radius.astronomicalUnits >= 0 else {
			throw .invalidRadius
		}
		self.init(uncheckedBody: body, gravitationalParameter: gravitationalParameter, radius: radius)
	}

	/// Creates a light-deflecting body without validation.
	///
	/// - Parameters:
	///   - body: The body.
	///   - gravitationalParameter: The gravitational parameter GM of the body, in au³/day²,
	///     finite and not negative.
	///   - radius: The radius of the body, finite and not negative.
	init(uncheckedBody body: Body, gravitationalParameter: Double, radius: Distance) {
		self.body = body
		self.gravitationalParameter = gravitationalParameter
		self.radius = radius
	}
}
