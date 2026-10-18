//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A plane angle, stored in radians.
///
/// An angle is not reduced to a single turn: arithmetic, comparison, and the stored value
/// keep every revolution, as needed for differences, rates, and series. Use ``normalized()``
/// or ``normalizedSigned()`` to reduce one.
///
/// An angle can be expressed in degrees, arcminutes, arcseconds, milliarcseconds, or hours of
/// time measure (``hourAngle``), where 24 hours make a turn. Conversions multiply by a
/// rounded constant, so a round trip such as `Angle(degrees: 30).degrees` can differ from
/// the original value in the last bit.
///
/// - Note: Values are not checked. An angle created from NaN or an infinity has that value
///   in every unit, as with `Double` arithmetic.
public struct Angle: Hashable, Sendable {
	/// The angle in radians.
	public let radians: Double

	/// Creates an angle from radians.
	///
	/// - Parameter radians: The angle in radians.
	public init(radians: Double) {
		self.radians = radians
	}
}

extension Angle {
	/// Radians per degree, π / 180.
	static let radiansPerDegree = Double.pi / 180
	/// Radians per arcminute, π / 10,800.
	static let radiansPerArcminute = Double.pi / 10_800
	/// Radians per arcsecond, π / 648,000.
	static let radiansPerArcsecond = Double.pi / 648_000
	/// Radians per milliarcsecond, π / 648,000,000.
	static let radiansPerMilliarcsecond = Double.pi / 648_000_000
	/// Radians per hour of time measure, π / 12.
	static let radiansPerHour = Double.pi / 12
	/// Radians per turn, 2π.
	static let radiansPerTurn = 2 * Double.pi

	/// Creates an angle from degrees.
	///
	/// - Parameter degrees: The angle in degrees.
	public init(degrees: Double) {
		self.init(radians: degrees * Self.radiansPerDegree)
	}

	/// Creates an angle from arcminutes.
	///
	/// - Parameter arcminutes: The angle in arcminutes.
	public init(arcminutes: Double) {
		self.init(radians: arcminutes * Self.radiansPerArcminute)
	}

	/// Creates an angle from arcseconds.
	///
	/// - Parameter arcseconds: The angle in arcseconds.
	public init(arcseconds: Double) {
		self.init(radians: arcseconds * Self.radiansPerArcsecond)
	}

	/// Creates an angle from milliarcseconds.
	///
	/// - Parameter milliarcseconds: The angle in milliarcseconds.
	public init(milliarcseconds: Double) {
		self.init(radians: milliarcseconds * Self.radiansPerMilliarcsecond)
	}

	/// Creates an angle from hours of time measure, where 1 hour is 15°.
	///
	/// Right ascension, hour angle, Earth rotation angle, and sidereal time are usually
	/// expressed in hours.
	///
	/// - Parameter hourAngle: The angle in hours.
	public init(hourAngle: Double) {
		self.init(radians: hourAngle * Self.radiansPerHour)
	}

	/// The angle in degrees.
	public var degrees: Double {
		radians / Self.radiansPerDegree
	}

	/// The angle in arcminutes.
	public var arcminutes: Double {
		radians / Self.radiansPerArcminute
	}

	/// The angle in arcseconds.
	public var arcseconds: Double {
		radians / Self.radiansPerArcsecond
	}

	/// The angle in milliarcseconds.
	public var milliarcseconds: Double {
		radians / Self.radiansPerMilliarcsecond
	}

	/// The angle in hours of time measure, where 1 hour is 15°.
	public var hourAngle: Double {
		radians / Self.radiansPerHour
	}
}

extension Angle {
	/// Returns the angle reduced to the right-open interval [0, 2π).
	///
	/// Use this for quantities measured around a full circle, such as longitude, right
	/// ascension, or Earth rotation angle.
	public func normalized() -> Angle {
		var r = radians.truncatingRemainder(dividingBy: Self.radiansPerTurn)
		if r < 0 {
			r += Self.radiansPerTurn
			// A tiny negative remainder rounds up to a whole turn.
			if r >= Self.radiansPerTurn {
				r = 0
			}
		}
		return Angle(radians: r)
	}

	/// Returns the angle reduced to the right-open interval [-π, π).
	///
	/// Use this for quantities signed about zero, such as hour angle or the difference
	/// between two longitudes.
	public func normalizedSigned() -> Angle {
		// The IEEE remainder lies in [-π, π].
		var r = radians.remainder(dividingBy: Self.radiansPerTurn)
		if r >= Double.pi {
			r -= Self.radiansPerTurn
		}
		return Angle(radians: r)
	}

	/// The absolute value of the angle.
	public var magnitude: Angle {
		Angle(radians: Swift.abs(radians))
	}
}

extension Angle {
	/// The sine of the angle.
	public var sin: Double {
		Math.sin(radians)
	}

	/// The cosine of the angle.
	public var cos: Double {
		Math.cos(radians)
	}

	/// The tangent of the angle.
	public var tan: Double {
		Math.tan(radians)
	}

	/// The sine and cosine of the angle.
	///
	/// Rotations need both, so this is a convenience for computing them together.
	public var sinCos: (sin: Double, cos: Double) {
		Math.sincos(radians)
	}

	/// Returns the angle whose sine is `x`, in the closed interval [-π/2, π/2].
	///
	/// - Parameter x: The sine, in [-1, 1]. Values outside that interval give NaN.
	/// - Returns: The arcsine of `x`.
	public static func asin(_ x: Double) -> Angle {
		Angle(radians: Math.asin(x))
	}

	/// Returns the angle whose cosine is `x`, in the closed interval [0, π].
	///
	/// - Parameter x: The cosine, in [-1, 1]. Values outside that interval give NaN.
	/// - Returns: The arccosine of `x`.
	public static func acos(_ x: Double) -> Angle {
		Angle(radians: Math.acos(x))
	}

	/// Returns the angle whose tangent is `x`, in the open interval (-π/2, π/2).
	///
	/// - Parameter x: The tangent.
	/// - Returns: The arctangent of `x`.
	public static func atan(_ x: Double) -> Angle {
		Angle(radians: Math.atan(x))
	}

	/// Returns the angle of the point (`x`, `y`) from the positive x axis, in [-π, π].
	///
	/// Unlike ``atan(_:)``, the result is in the correct quadrant. Use ``normalized()`` to
	/// reduce it to [0, 2π), as for right ascension.
	///
	/// - Parameters:
	///   - y: The y coordinate.
	///   - x: The x coordinate.
	/// - Returns: The arctangent of `y / x` in the quadrant of (`x`, `y`).
	public static func atan2(y: Double, x: Double) -> Angle {
		Angle(radians: Math.atan2(y, x))
	}
}

extension Angle: AdditiveArithmetic {
	/// The zero angle.
	public static let zero = Angle(radians: 0)

	public static func + (lhs: Angle, rhs: Angle) -> Angle {
		Angle(radians: lhs.radians + rhs.radians)
	}

	public static func - (lhs: Angle, rhs: Angle) -> Angle {
		Angle(radians: lhs.radians - rhs.radians)
	}

	/// Returns the angle with its sign reversed.
	public static prefix func - (operand: Angle) -> Angle {
		Angle(radians: -operand.radians)
	}
}

extension Angle {
	/// Returns the angle scaled by a factor.
	public static func * (lhs: Angle, rhs: Double) -> Angle {
		Angle(radians: lhs.radians * rhs)
	}

	/// Returns the angle scaled by a factor.
	public static func * (lhs: Double, rhs: Angle) -> Angle {
		Angle(radians: lhs * rhs.radians)
	}

	/// Returns the angle divided by a divisor.
	public static func / (lhs: Angle, rhs: Double) -> Angle {
		Angle(radians: lhs.radians / rhs)
	}

	/// Returns the ratio of two angles.
	public static func / (lhs: Angle, rhs: Angle) -> Double {
		lhs.radians / rhs.radians
	}

	/// Scales the angle by a factor.
	public static func *= (lhs: inout Angle, rhs: Double) {
		lhs = lhs * rhs
	}

	/// Divides the angle by a divisor.
	public static func /= (lhs: inout Angle, rhs: Double) {
		lhs = lhs / rhs
	}
}

extension Angle: Comparable {
	/// Returns `true` if the first angle is smaller than the second.
	///
	/// Angles are compared without reduction, so 350° is greater than -10°.
	public static func < (lhs: Angle, rhs: Angle) -> Bool {
		lhs.radians < rhs.radians
	}
}

extension Angle: CustomStringConvertible {
	/// A textual representation of the angle in degrees, such as `30.0°`.
	public var description: String {
		"\(degrees)°"
	}
}

extension Angle: Codable {
	/// Creates an angle by decoding it from a single value in radians.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: Any error thrown by `decoder`.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.init(radians: try container.decode(Double.self))
	}

	/// Encodes the angle as a single value in radians.
	///
	/// - Parameter encoder: The encoder to write data to.
	/// - Throws: Any error thrown by `encoder`.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(radians)
	}
}
