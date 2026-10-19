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
/// relative to the other.
public struct Velocity<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The components in astronomical units per day.
	let vector: Vector3

	/// Creates a velocity from components in astronomical units per day.
	init(_ vector: Vector3) {
		self.vector = vector
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
		let scale = secondsPerDay / Distance.kilometersPerAstronomicalUnit
		self.init(Vector3(components.x * scale, components.y * scale, components.z * scale))
	}
}

extension Velocity {
	/// The components along the frame's x, y, and z axes, in astronomical units per day.
	public var astronomicalUnitsPerDay: SIMD3<Double> {
		SIMD3(vector.x, vector.y, vector.z)
	}

	/// The components along the frame's x, y, and z axes, in kilometers per second.
	public var kilometersPerSecond: SIMD3<Double> {
		astronomicalUnitsPerDay * (Distance.kilometersPerAstronomicalUnit / secondsPerDay)
	}

	/// Returns the displacement at this velocity over a number of days.
	///
	/// - Parameter days: The number of days, which can be negative.
	/// - Returns: The change in position.
	public func displacement(overDays days: Double) -> Position<Frame> {
		Position(vector * days)
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

extension Velocity: AdditiveArithmetic {
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

extension Velocity {
	/// Returns the velocity reversed.
	public static prefix func - (operand: Velocity) -> Velocity {
		Velocity(-operand.vector)
	}
}

extension Velocity {
	/// Returns the velocity scaled by a factor.
	public static func * (lhs: Velocity, rhs: Double) -> Velocity {
		Velocity(lhs.vector * rhs)
	}

	/// Returns the velocity scaled by a factor.
	public static func * (lhs: Double, rhs: Velocity) -> Velocity {
		Velocity(lhs * rhs.vector)
	}

	/// Returns the velocity divided by a divisor.
	public static func / (lhs: Velocity, rhs: Double) -> Velocity {
		Velocity(lhs.vector / rhs)
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

extension Rotation {
	/// Returns a velocity in the `From` frame expressed in the `To` frame.
	public static func * (lhs: Rotation, rhs: Velocity<From>) -> Velocity<To> {
		Velocity(lhs.apply(to: rhs.vector))
	}
}

extension Velocity: CustomStringConvertible {
	/// A textual representation of the components in astronomical units per day and the
	/// frame, such as `(0.0, 0.017, 0.0) au/d ICRS`.
	public var description: String {
		"(\(vector.x), \(vector.y), \(vector.z)) au/d \(Frame.name)"
	}
}
