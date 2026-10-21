//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A position as rectangular coordinates in a reference frame.
///
/// The frame fixes the directions of the axes, but not the origin, so a position is relative
/// to whatever origin it was computed from, such as the solar system barycenter, the Sun, or
/// the Earth. Subtracting two positions with the same origin gives the position of one
/// relative to the other.
///
/// Use ``spherical`` for the direction and distance, or ``init(_:)`` to create a position from
/// them.
///
/// A position in a frame with an epoch, such as a ``DatedReferenceFrame`` or the ``TIRS``,
/// also carries the frame's ``epoch``. Positions at different epochs are in different frames,
/// so in such a frame `adding(_:)`, `subtracting(_:)`, and `angularSeparation(from:)` throw
/// when the epochs differ, in place of the `+` and `-` of frames without an epoch.
public struct Position<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The coordinates in astronomical units.
	let vector: Vector3
	/// The epoch of the frame, ``NoEpoch`` for a frame without one.
	let frameEpoch: Frame.Epoch

	/// Creates a position from coordinates in astronomical units at an epoch of the frame.
	init(_ vector: Vector3, frameEpoch: Frame.Epoch) {
		self.vector = vector
		self.frameEpoch = frameEpoch
	}
}

extension Position {
	/// The coordinate along the frame's x axis.
	public var x: Distance {
		Distance(astronomicalUnits: vector.x)
	}

	/// The coordinate along the frame's y axis.
	public var y: Distance {
		Distance(astronomicalUnits: vector.y)
	}

	/// The coordinate along the frame's z axis.
	public var z: Distance {
		Distance(astronomicalUnits: vector.z)
	}

	/// The distance from the origin.
	public var distance: Distance {
		Distance(astronomicalUnits: vector.length)
	}

	/// Returns the angle between the directions of two positions from the origin, whatever
	/// their epochs.
	func separation(from other: Position) -> Angle {
		// With the origin the dot product is a zero whose sign depends on the coordinates,
		// and atan2(+0, -0) would give π.
		if vector == .zero || other.vector == .zero {
			return .zero
		}
		return Angle.atan2(y: vector.cross(other.vector).length, x: vector.dot(other.vector))
	}

	/// Returns the position reflected through the origin.
	public static prefix func - (operand: Position) -> Position {
		Position(-operand.vector, frameEpoch: operand.frameEpoch)
	}

	/// Returns the position scaled by a factor.
	public static func * (lhs: Position, rhs: Double) -> Position {
		Position(lhs.vector * rhs, frameEpoch: lhs.frameEpoch)
	}

	/// Returns the position scaled by a factor.
	public static func * (lhs: Double, rhs: Position) -> Position {
		Position(lhs * rhs.vector, frameEpoch: rhs.frameEpoch)
	}

	/// Returns the position divided by a divisor.
	public static func / (lhs: Position, rhs: Double) -> Position {
		Position(lhs.vector / rhs, frameEpoch: lhs.frameEpoch)
	}

	/// Scales the position by a factor.
	public static func *= (lhs: inout Position, rhs: Double) {
		lhs = lhs * rhs
	}

	/// Divides the position by a divisor.
	public static func /= (lhs: inout Position, rhs: Double) {
		lhs = lhs / rhs
	}
}

extension Position where Frame.Epoch == NoEpoch {
	/// Creates a position from coordinates in astronomical units.
	init(_ vector: Vector3) {
		self.init(vector, frameEpoch: NoEpoch())
	}

	/// Creates a position from rectangular coordinates.
	///
	/// - Parameters:
	///   - x: The coordinate along the frame's x axis.
	///   - y: The coordinate along the frame's y axis.
	///   - z: The coordinate along the frame's z axis.
	public init(x: Distance, y: Distance, z: Distance) {
		self.init(Vector3(x.astronomicalUnits, y.astronomicalUnits, z.astronomicalUnits))
	}

	/// The position at the origin.
	public static var origin: Position { Position(.zero) }

	/// Returns the angle between the directions of two positions from the origin.
	///
	/// The angle is computed from both the sine and the cosine, so it is accurate for small
	/// and nearly opposite separations alike.
	///
	/// - Parameter other: Another position in the same frame.
	/// - Returns: The angle, in the closed interval [0, π], or zero if either position is the
	///   origin.
	public func angularSeparation(from other: Position) -> Angle {
		separation(from: other)
	}
}

extension Position where Frame: FixedReferenceFrame {
	/// Returns the same position in another frame fixed relative to the ICRS.
	///
	/// - Parameter frame: The frame to express the position in.
	/// - Returns: The position in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type) -> Position<Target> {
		Frame.rotation(to: frame) * self
	}
}

/// Positions in a frame without an epoch, such as a fixed frame or the ITRS, form an additive
/// group with the origin as zero. A frame with an epoch has no zero without one, so its
/// positions don't conform.
extension Position: AdditiveArithmetic where Frame.Epoch == NoEpoch {
	/// The position at the origin.
	public static var zero: Position { .origin }

	/// Returns the sum of two positions, as for a position relative to an intermediate
	/// origin added to that origin's position.
	public static func + (lhs: Position, rhs: Position) -> Position {
		Position(lhs.vector + rhs.vector)
	}

	/// Returns the position of `lhs` relative to `rhs`, given positions from the same origin.
	public static func - (lhs: Position, rhs: Position) -> Position {
		Position(lhs.vector - rhs.vector)
	}
}

extension Position where Frame.Epoch == Instant<TT> {
	/// Creates a position from rectangular coordinates in a frame with an epoch.
	///
	/// - Parameters:
	///   - x: The coordinate along the frame's x axis.
	///   - y: The coordinate along the frame's y axis.
	///   - z: The coordinate along the frame's z axis.
	///   - epoch: The epoch of the frame.
	public init(x: Distance, y: Distance, z: Distance, epoch: Instant<TT>) {
		self.init(Vector3(x.astronomicalUnits, y.astronomicalUnits, z.astronomicalUnits), frameEpoch: epoch)
	}

	/// The position at the origin of a frame with an epoch.
	///
	/// - Parameter epoch: The epoch of the frame.
	public static func origin(epoch: Instant<TT>) -> Position {
		Position(.zero, frameEpoch: epoch)
	}

	/// The epoch of the frame: the instant whose equator, equinox, or ecliptic fixes the
	/// axes.
	public var epoch: Instant<TT> {
		frameEpoch
	}

	/// Returns the angle between the directions of two positions from the origin.
	///
	/// The angle is computed from both the sine and the cosine, so it is accurate for small
	/// and nearly opposite separations alike.
	///
	/// - Parameter other: Another position in the same frame, at the same epoch.
	/// - Returns: The angle, in the closed interval [0, π], or zero if either position is the
	///   origin.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public func angularSeparation(from other: Position) throws(CoordinateError) -> Angle {
		try checkSameEpoch(epoch, other.epoch)
		return separation(from: other)
	}

	/// Returns the sum of two positions, as for a position relative to an intermediate
	/// origin added to that origin's position.
	///
	/// - Parameter other: The position to add, at the same epoch.
	/// - Returns: The sum, at the same epoch.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public func adding(_ other: Position) throws(CoordinateError) -> Position {
		try checkSameEpoch(epoch, other.epoch)
		return Position(vector + other.vector, frameEpoch: frameEpoch)
	}

	/// Returns the position relative to another, given positions from the same origin.
	///
	/// - Parameter other: The position to subtract, at the same epoch.
	/// - Returns: The difference, at the same epoch.
	/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
	public func subtracting(_ other: Position) throws(CoordinateError) -> Position {
		try checkSameEpoch(epoch, other.epoch)
		return Position(vector - other.vector, frameEpoch: frameEpoch)
	}
}

extension Position: CustomStringConvertible {
	/// A textual representation of the coordinates in astronomical units, the frame, and any
	/// epoch of the frame, such as `(1.0, 0.0, 0.0) au ICRS`.
	public var description: String {
		"(\(vector.x), \(vector.y), \(vector.z)) au \(Frame.name)\(epochDescription(frameEpoch))"
	}
}

/// The epoch of a frame for a description, such as ` at JD 2451545 TT`, or nothing for a fixed
/// frame.
func epochDescription(_ epoch: some Hashable) -> String {
	epoch is NoEpoch ? "" : " at \(epoch)"
}
