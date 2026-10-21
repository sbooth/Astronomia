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
/// state of one body relative to the other, as for Mars seen from the Earth. In a frame with an
/// epoch, such as a ``DatedReferenceFrame`` or the ``TIRS``, it carries the frame's ``epoch``,
/// which need not be the instant of the state.
public struct StateVector<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The position.
	public let position: Position<Frame>
	/// The velocity.
	public let velocity: Velocity<Frame>

	/// Creates a state vector from a position and a velocity at the same epoch of the frame.
	init(uncheckedPosition position: Position<Frame>, velocity: Velocity<Frame>) {
		self.position = position
		self.velocity = velocity
	}
}

extension StateVector {
	/// Returns the state of the origin relative to the body.
	public static prefix func - (operand: StateVector) -> StateVector {
		StateVector(uncheckedPosition: -operand.position, velocity: -operand.velocity)
	}

	/// Returns the state scaled by a factor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func * (lhs: StateVector, rhs: Double) -> StateVector {
		StateVector(uncheckedPosition: lhs.position * rhs, velocity: lhs.velocity * rhs)
	}

	/// Returns the state scaled by a factor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func * (lhs: Double, rhs: StateVector) -> StateVector {
		StateVector(uncheckedPosition: lhs * rhs.position, velocity: lhs * rhs.velocity)
	}

	/// Returns the state divided by a divisor, as for a point a fraction of the way from the
	/// origin to the body.
	public static func / (lhs: StateVector, rhs: Double) -> StateVector {
		StateVector(uncheckedPosition: lhs.position / rhs, velocity: lhs.velocity / rhs)
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

extension StateVector where Frame.Epoch == NoEpoch {
	/// Creates a state vector from a position and a velocity.
	///
	/// - Parameters:
	///   - position: The position.
	///   - velocity: The velocity.
	public init(position: Position<Frame>, velocity: Velocity<Frame>) {
		self.init(uncheckedPosition: position, velocity: velocity)
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

/// States in a frame without an epoch form an additive group with the origin at rest as zero. A
/// frame with an epoch has no zero without one, so its states don't conform.
extension StateVector: AdditiveArithmetic where Frame.Epoch == NoEpoch {
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

extension StateVector where Frame.Epoch == Instant<TT> {
	/// Creates a state vector from a position and a velocity in a frame with an epoch.
	///
	/// - Parameters:
	///   - position: The position.
	///   - velocity: The velocity, at the position's epoch.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public init(position: Position<Frame>, velocity: Velocity<Frame>) throws(CoordinateError) {
		try checkSameEpoch(position.epoch, velocity.epoch)
		self.init(uncheckedPosition: position, velocity: velocity)
	}

	/// The epoch of the frame: the instant whose equator, equinox, or ecliptic fixes the
	/// axes.
	public var epoch: Instant<TT> {
		position.epoch
	}

	/// Returns the sum of two states, as for a state relative to an intermediate origin added
	/// to that origin's state.
	///
	/// - Parameter other: The state to add, at the same epoch.
	/// - Returns: The sum, at the same epoch.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public func adding(_ other: StateVector) throws(CoordinateError) -> StateVector {
		try StateVector(uncheckedPosition: position.adding(other.position), velocity: velocity.adding(other.velocity))
	}

	/// Returns the state relative to another, given states from the same origin.
	///
	/// - Parameter other: The state to subtract, at the same epoch.
	/// - Returns: The difference, at the same epoch.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public func subtracting(_ other: StateVector) throws(CoordinateError) -> StateVector {
		try StateVector(uncheckedPosition: position.subtracting(other.position), velocity: velocity.subtracting(other.velocity))
	}
}

extension StateVector: CustomStringConvertible {
	/// A textual representation of the position and the velocity.
	public var description: String {
		"position \(position), velocity \(velocity)"
	}
}
