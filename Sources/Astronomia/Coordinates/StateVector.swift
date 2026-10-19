//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The position and velocity of a body at one instant, relative to one origin, in a reference
/// frame.
///
/// A state vector does not record its instant or its origin, which are those of the request
/// that produced it. Subtracting two state vectors with the same origin and instant gives the
/// state of one body relative to the other, as for Mars seen from the Earth.
public struct StateVector<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The position.
	public let position: Position<Frame>
	/// The velocity.
	public let velocity: Velocity<Frame>

	/// Creates a state vector from a position and a velocity.
	///
	/// - Parameters:
	///   - position: The position.
	///   - velocity: The velocity.
	public init(position: Position<Frame>, velocity: Velocity<Frame>) {
		self.position = position
		self.velocity = velocity
	}

	/// Creates a state vector from a position in astronomical units and a velocity in
	/// astronomical units per day.
	init(_ position: Vector3, _ velocity: Vector3) {
		self.init(position: Position(position), velocity: Velocity(velocity))
	}
}

extension StateVector where Frame: FixedReferenceFrame {
	/// Returns the same state in another frame fixed relative to the ICRS.
	///
	/// - Parameter frame: The frame to express the state in.
	/// - Returns: The state in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type) -> StateVector<Target> {
		let rotation = Frame.rotation(to: frame)
		return StateVector<Target>(position: rotation * position, velocity: rotation * velocity)
	}
}

extension StateVector: AdditiveArithmetic {
	/// The position and velocity of a body at rest at the origin; alternatively, the state of
	/// the origin itself.
	public static var zero: StateVector {
		StateVector(.zero, .zero)
	}

	/// Returns the sum of two states, as for a state relative to an intermediate origin added
	/// to that origin's state.
	public static func + (lhs: StateVector, rhs: StateVector) -> StateVector {
		StateVector(position: lhs.position + rhs.position, velocity: lhs.velocity + rhs.velocity)
	}

	/// Returns the state of `lhs` relative to `rhs`, given states from the same origin.
	public static func - (lhs: StateVector, rhs: StateVector) -> StateVector {
		StateVector(position: lhs.position - rhs.position, velocity: lhs.velocity - rhs.velocity)
	}
}

extension StateVector {
	/// Returns the state of the origin relative to the body.
	public static prefix func - (operand: StateVector) -> StateVector {
		StateVector(position: -operand.position, velocity: -operand.velocity)
	}
}

extension StateVector {
	/// Returns the state scaled by a factor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func * (lhs: StateVector, rhs: Double) -> StateVector {
		StateVector(position: lhs.position * rhs, velocity: lhs.velocity * rhs)
	}

	/// Returns the state scaled by a factor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func * (lhs: Double, rhs: StateVector) -> StateVector {
		StateVector(position: lhs * rhs.position, velocity: lhs * rhs.velocity)
	}

	/// Returns the state divided by a divisor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func / (lhs: StateVector, rhs: Double) -> StateVector {
		StateVector(position: lhs.position / rhs, velocity: lhs.velocity / rhs)
	}

	/// Scales the state by a factor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func *= (lhs: inout StateVector, rhs: Double) {
		lhs = lhs * rhs
	}

	/// Divides the state by a divisor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func /= (lhs: inout StateVector, rhs: Double) {
		lhs = lhs / rhs
	}
}

extension StateVector: CustomStringConvertible {
	/// A textual representation of the position and the velocity.
	public var description: String {
		"position \(position), velocity \(velocity)"
	}
}
