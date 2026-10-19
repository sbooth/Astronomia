//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A three-dimensional vector of `Double` components, without units or a frame.
///
/// Typed values such as ``Position`` store their components in one, and give them units and
/// a frame.
struct Vector3: Hashable, Sendable {
	/// The x component.
	let x: Double
	/// The y component.
	let y: Double
	/// The z component.
	let z: Double

	/// Creates a vector from its components.
	init(_ x: Double, _ y: Double, _ z: Double) {
		self.x = x
		self.y = y
		self.z = z
	}

	/// The zero vector.
	static let zero = Vector3(0, 0, 0)

	/// The Euclidean length.
	var length: Double {
		dot(self).squareRoot()
	}

	/// Returns the dot product with another vector.
	func dot(_ other: Vector3) -> Double {
		x * other.x + y * other.y + z * other.z
	}

	/// Returns the cross product with another vector, `self × other`.
	func cross(_ other: Vector3) -> Vector3 {
		Vector3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
	}

	static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
		Vector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
	}

	static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
		Vector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
	}

	static prefix func - (operand: Vector3) -> Vector3 {
		Vector3(-operand.x, -operand.y, -operand.z)
	}

	static func * (lhs: Vector3, rhs: Double) -> Vector3 {
		Vector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
	}

	static func * (lhs: Double, rhs: Vector3) -> Vector3 {
		rhs * lhs
	}

	static func / (lhs: Vector3, rhs: Double) -> Vector3 {
		Vector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
	}
}

extension Vector3 {
	/// The vector as a SIMD3\<Double\>.
	var simd3: SIMD3<Double> { SIMD3(x: x, y: y, z: z) }
}
