//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A velocity as rectangular components in a reference frame.
///
/// Like ``Position``, a velocity is relative to an origin that the frame does not fix:
/// subtracting the velocities of two bodies from the same origin gives the velocity of one
/// relative to the other. In a frame with an epoch, such as a ``DatedReferenceFrame`` or the
/// ``TIRS``, it also carries the frame's ``epoch``, and `adding(_:)` and `subtracting(_:)`
/// throw when the epochs differ, in place of the `+` and `-` of frames without an epoch.
public struct Velocity<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The components in astronomical units per day.
	let vector: Vector3
	/// The epoch of the frame, ``NoEpoch`` for a frame without one.
	let frameEpoch: Frame.Epoch

	/// Creates a velocity from components in astronomical units per day at an epoch of the
	/// frame.
	init(_ vector: Vector3, frameEpoch: Frame.Epoch) {
		self.vector = vector
		self.frameEpoch = frameEpoch
	}
}

extension Velocity {
	/// Returns components in kilometers per second in astronomical units per day.
	static func astronomicalUnitsPerDay(fromKilometersPerSecond components: SIMD3<Double>) -> Vector3 {
		let scale = secondsPerDay / kilometersPerAstronomicalUnit
		return Vector3(components.x * scale, components.y * scale, components.z * scale)
	}

	/// The components along the frame's x, y, and z axes, in astronomical units per day.
	public var astronomicalUnitsPerDay: SIMD3<Double> {
		SIMD3(vector.x, vector.y, vector.z)
	}

	/// The components along the frame's x, y, and z axes, in kilometers per second.
	public var kilometersPerSecond: SIMD3<Double> {
		astronomicalUnitsPerDay * (kilometersPerAstronomicalUnit / secondsPerDay)
	}

	/// Returns the displacement at this velocity over a number of days.
	///
	/// - Parameter days: The number of days, which can be negative.
	/// - Returns: The change in position.
	public func displacement(overDays days: Double) -> Position<Frame> {
		Position(vector * days, frameEpoch: frameEpoch)
	}

	/// Returns the velocity reversed.
	public static prefix func - (operand: Velocity) -> Velocity {
		Velocity(-operand.vector, frameEpoch: operand.frameEpoch)
	}

	/// Returns the velocity scaled by a factor.
	public static func * (lhs: Velocity, rhs: Double) -> Velocity {
		Velocity(lhs.vector * rhs, frameEpoch: lhs.frameEpoch)
	}

	/// Returns the velocity scaled by a factor.
	public static func * (lhs: Double, rhs: Velocity) -> Velocity {
		Velocity(lhs * rhs.vector, frameEpoch: rhs.frameEpoch)
	}

	/// Returns the velocity divided by a divisor.
	public static func / (lhs: Velocity, rhs: Double) -> Velocity {
		Velocity(lhs.vector / rhs, frameEpoch: lhs.frameEpoch)
	}

	/// Scales the velocity by a factor.
	public static func *= (lhs: inout Velocity, rhs: Double) {
		lhs = lhs * rhs
	}

	/// Divides the velocity by a divisor.
	public static func /= (lhs: inout Velocity, rhs: Double) {
		lhs = lhs / rhs
	}
}

extension Velocity where Frame.Epoch == NoEpoch {
	/// Creates a velocity from components in astronomical units per day.
	init(_ vector: Vector3) {
		self.init(vector, frameEpoch: NoEpoch())
	}

	/// Creates a velocity from components in astronomical units per day.
	///
	/// - Parameter astronomicalUnitsPerDay: The components along the frame's x, y, and z
	///   axes.
	public init(astronomicalUnitsPerDay components: SIMD3<Double>) {
		self.init(Vector3(components.x, components.y, components.z))
	}

	/// Creates a velocity from components in kilometers per second.
	///
	/// - Parameter kilometersPerSecond: The components along the frame's x, y, and z axes.
	public init(kilometersPerSecond components: SIMD3<Double>) {
		self.init(Self.astronomicalUnitsPerDay(fromKilometersPerSecond: components))
	}
}

extension Velocity where Frame: FixedReferenceFrame {
	/// Returns the same velocity in another frame fixed relative to the ICRS.
	///
	/// - Parameter frame: The frame to express the velocity in.
	/// - Returns: The velocity in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type) -> Velocity<Target> {
		Frame.rotation(to: frame) * self
	}
}

/// Velocities in a frame without an epoch form an additive group with rest as zero. A frame
/// with an epoch has no zero without one, so its velocities don't conform.
extension Velocity: AdditiveArithmetic where Frame.Epoch == NoEpoch {
	/// The velocity of a body at rest relative to the origin.
	public static var zero: Velocity {
		Velocity(.zero)
	}

	/// Returns the sum of two velocities, as for a velocity relative to a moving origin added to
	/// that origin's velocity.
	public static func + (lhs: Velocity, rhs: Velocity) -> Velocity {
		Velocity(lhs.vector + rhs.vector)
	}

	/// Returns the velocity of `lhs` relative to `rhs`, given velocities from the same origin.
	public static func - (lhs: Velocity, rhs: Velocity) -> Velocity {
		Velocity(lhs.vector - rhs.vector)
	}
}

extension Velocity where Frame.Epoch == Instant<TT> {
	/// Creates a velocity from components in astronomical units per day in a frame with an
	/// epoch.
	///
	/// - Parameters:
	///   - astronomicalUnitsPerDay: The components along the frame's x, y, and z axes.
	///   - epoch: The epoch of the frame.
	public init(astronomicalUnitsPerDay components: SIMD3<Double>, epoch: Instant<TT>) {
		self.init(Vector3(components.x, components.y, components.z), frameEpoch: epoch)
	}

	/// Creates a velocity from components in kilometers per second in a frame with an epoch.
	///
	/// - Parameters:
	///   - kilometersPerSecond: The components along the frame's x, y, and z axes.
	///   - epoch: The epoch of the frame.
	public init(kilometersPerSecond components: SIMD3<Double>, epoch: Instant<TT>) {
		self.init(Self.astronomicalUnitsPerDay(fromKilometersPerSecond: components), frameEpoch: epoch)
	}

	/// The velocity of a body at rest relative to the origin of a frame with an epoch.
	///
	/// - Parameter epoch: The epoch of the frame.
	public static func zero(epoch: Instant<TT>) -> Velocity {
		Velocity(.zero, frameEpoch: epoch)
	}

	/// The epoch of the frame: the instant whose equator, equinox, or ecliptic fixes the
	/// axes.
	public var epoch: Instant<TT> {
		frameEpoch
	}

	/// Returns the sum of two velocities, as for a velocity relative to a moving origin added to
	/// that origin's velocity.
	///
	/// - Parameter other: The velocity to add, at the same epoch.
	/// - Returns: The sum, at the same epoch.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public func adding(_ other: Velocity) throws(CoordinateError) -> Velocity {
		try checkSameEpoch(epoch, other.epoch)
		return Velocity(vector + other.vector, frameEpoch: frameEpoch)
	}

	/// Returns the velocity relative to another, given velocities from the same origin.
	///
	/// - Parameter other: The velocity to subtract, at the same epoch.
	/// - Returns: The difference, at the same epoch.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public func subtracting(_ other: Velocity) throws(CoordinateError) -> Velocity {
		try checkSameEpoch(epoch, other.epoch)
		return Velocity(vector - other.vector, frameEpoch: frameEpoch)
	}
}

extension Rotation where From.Epoch == NoEpoch {
	/// Returns a velocity in the `From` frame expressed in the `To` frame.
	public static func * (lhs: Rotation, rhs: Velocity<From>) -> Velocity<To> {
		Velocity<To>(lhs.apply(to: rhs.vector), frameEpoch: lhs.toFrameEpoch)
	}
}

extension Rotation where From.Epoch == Instant<TT> {
	/// Returns a velocity in the `From` frame of date expressed in the `To` frame.
	///
	/// - Parameter velocity: A velocity at the rotation's `From` epoch.
	/// - Returns: The same velocity in the `To` frame.
	/// - Throws: ``CoordinateError/epochMismatch`` if the velocity is at another epoch.
	public func apply(to velocity: Velocity<From>) throws(CoordinateError) -> Velocity<To> {
		try checkSameEpoch(fromEpoch, velocity.epoch)
		return Velocity<To>(apply(to: velocity.vector), frameEpoch: toFrameEpoch)
	}
}

extension Velocity: CustomStringConvertible {
	/// A textual representation of the components in astronomical units per day, the frame,
	/// and any epoch of the frame, such as `(0.0, 0.017, 0.0) au/d ICRS`.
	public var description: String {
		"(\(vector.x), \(vector.y), \(vector.z)) au/d \(Frame.name)\(epochDescription(frameEpoch))"
	}
}
