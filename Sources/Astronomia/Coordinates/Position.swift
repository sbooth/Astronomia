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
public struct Position<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The coordinates in astronomical units.
	let vector: Vector3

	/// Creates a position from coordinates in astronomical units.
	init(_ vector: Vector3) {
		self.vector = vector
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
}

extension Position {
	/// The position at the origin.
	public static var origin: Position {
		Position(.zero)
	}

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

	/// Returns the angle between the directions of two positions from the origin.
	///
	/// The angle is computed from both the sine and the cosine, so it is accurate for small
	/// and nearly opposite separations alike.
	///
	/// - Parameter other: Another position in the same frame.
	/// - Returns: The angle, in the closed interval [0, π], or zero if either position is the
	///   origin.
	public func angularSeparation(from other: Position) -> Angle {
		// With the origin the dot product is a zero whose sign depends on the coordinates,
		// and atan2(+0, -0) would give π.
		if vector == .zero || other.vector == .zero {
			return .zero
		}
		return Angle.atan2(y: vector.cross(other.vector).length, x: vector.dot(other.vector))
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

extension Position: AdditiveArithmetic {
	/// The position at the origin.
	public static var zero: Position {
		.origin
	}

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

extension Position {
	/// Returns the position reflected through the origin.
	public static prefix func - (operand: Position) -> Position {
		Position(-operand.vector)
	}
}

extension Position {
	/// Returns the position scaled by a factor.
	public static func * (lhs: Position, rhs: Double) -> Position {
		Position(lhs.vector * rhs)
	}

	/// Returns the position scaled by a factor.
	public static func * (lhs: Double, rhs: Position) -> Position {
		Position(lhs * rhs.vector)
	}

	/// Returns the position divided by a divisor.
	public static func / (lhs: Position, rhs: Double) -> Position {
		Position(lhs.vector / rhs)
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

extension Position: CustomStringConvertible {
	/// A textual representation of the coordinates in astronomical units and the frame, such
	/// as `(1.0, 0.0, 0.0) au ICRS`.
	public var description: String {
		"(\(vector.x), \(vector.y), \(vector.z)) au \(Frame.name)"
	}
}
