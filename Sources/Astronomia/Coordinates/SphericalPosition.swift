//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A position as a direction and distance in a reference frame.
///
/// Longitude is measured in the frame's fundamental plane from the x axis toward the y axis,
/// and latitude from that plane toward the z axis. In an ``EquatorialFrame`` they are right
/// ascension and declination, and in an ``EclipticFrame`` ecliptic longitude and latitude. In
/// a frame of date, a ``DatedReferenceFrame``, it also carries the frame's epoch.
public struct SphericalPosition<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The longitude, in the right-open interval [0, 2π).
	public let longitude: Angle
	/// The latitude, in the closed interval [-π/2, π/2] for a position computed from
	/// rectangular coordinates.
	public let latitude: Angle
	/// The distance from the origin.
	public let distance: Distance
	/// The epoch of the frame, ``NoEpoch`` for a fixed frame.
	let frameEpoch: Frame.Epoch

	/// Creates a spherical position at an epoch of the frame, reducing the longitude to
	/// [0, 2π).
	init(longitude: Angle, latitude: Angle, distance: Distance, frameEpoch: Frame.Epoch) {
		self.longitude = longitude.normalized()
		self.latitude = latitude
		self.distance = distance
		self.frameEpoch = frameEpoch
	}
}

extension SphericalPosition where Frame: FixedReferenceFrame {
	/// Creates a spherical position.
	///
	/// The longitude is reduced to [0, 2π). A latitude outside [-π/2, π/2] is kept as given; it
	/// still describes a direction, the one reached by continuing over the pole.
	///
	/// - Parameters:
	///   - longitude: The longitude.
	///   - latitude: The latitude.
	///   - distance: The distance from the origin.
	public init(longitude: Angle, latitude: Angle, distance: Distance) {
		self.init(longitude: longitude, latitude: latitude, distance: distance, frameEpoch: NoEpoch())
	}
}

extension SphericalPosition where Frame: DatedReferenceFrame {
	/// Creates a spherical position in a frame of date.
	///
	/// The longitude is reduced to [0, 2π). A latitude outside [-π/2, π/2] is kept as given; it
	/// still describes a direction, the one reached by continuing over the pole.
	///
	/// - Parameters:
	///   - longitude: The longitude.
	///   - latitude: The latitude.
	///   - distance: The distance from the origin.
	///   - epoch: The epoch of the frame.
	public init(longitude: Angle, latitude: Angle, distance: Distance, epoch: Instant<TT>) {
		self.init(longitude: longitude, latitude: latitude, distance: distance, frameEpoch: epoch)
	}

	/// The epoch of the frame: the instant whose equator, equinox, or ecliptic fixes the
	/// axes.
	public var epoch: Instant<TT> {
		frameEpoch
	}
}

extension SphericalPosition where Frame: EquatorialFrame & FixedReferenceFrame {
	/// Creates a spherical position from right ascension and declination.
	///
	/// - Parameters:
	///   - rightAscension: The right ascension.
	///   - declination: The declination.
	///   - distance: The distance from the origin.
	public init(rightAscension: Angle, declination: Angle, distance: Distance) {
		self.init(longitude: rightAscension, latitude: declination, distance: distance)
	}
}

extension SphericalPosition where Frame: EquatorialFrame & DatedReferenceFrame {
	/// Creates a spherical position from right ascension and declination in a frame of date.
	///
	/// - Parameters:
	///   - rightAscension: The right ascension.
	///   - declination: The declination.
	///   - distance: The distance from the origin.
	///   - epoch: The epoch of the frame.
	public init(rightAscension: Angle, declination: Angle, distance: Distance, epoch: Instant<TT>) {
		self.init(longitude: rightAscension, latitude: declination, distance: distance, epoch: epoch)
	}
}

extension SphericalPosition where Frame: EquatorialFrame {
	/// The right ascension, in the right-open interval [0, 2π).
	public var rightAscension: Angle {
		longitude
	}

	/// The declination, in the closed interval [-π/2, π/2].
	public var declination: Angle {
		latitude
	}
}

extension Position {
	/// Creates a position from a direction and distance.
	///
	/// - Parameter spherical: The spherical position.
	public init(_ spherical: SphericalPosition<Frame>) {
		let (sinLon, cosLon) = spherical.longitude.sinCos
		let (sinLat, cosLat) = spherical.latitude.sinCos
		let r = spherical.distance.astronomicalUnits
		self.init(Vector3(r * cosLat * cosLon, r * cosLat * sinLon, r * sinLat), frameEpoch: spherical.frameEpoch)
	}

	/// The direction and distance of the position.
	///
	/// The latitude is computed with the arctangent of the z coordinate over the distance from
	/// the z axis, which keeps full precision near the poles. At the origin the longitude and
	/// latitude are zero, and on the z axis the longitude is zero.
	public var spherical: SphericalPosition<Frame> {
		let rho = (vector.x * vector.x + vector.y * vector.y).squareRoot()
		// On the z axis the longitude is undefined. The arctangent of two zeros depends on
		// their signs, and atan2(-0, -0), as for a negated position, would give 180°.
		let onAxis = vector.x == 0 && vector.y == 0
		return SphericalPosition(
			longitude: onAxis ? .zero : Angle.atan2(y: vector.y, x: vector.x),
			latitude: Angle.atan2(y: vector.z, x: rho),
			distance: distance,
			frameEpoch: frameEpoch
		)
	}
}
