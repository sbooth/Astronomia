//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import CAstronomyEngine

/// A 3D Cartesian vector whose components are expressed in Astronomical Units (AU).
public struct Vector: Hashable {
	/// The Cartesian x-coordinate in AU.
	public let x: Double
	/// The Cartesian y-coordinate in AU.
	public let y: Double
	/// The Cartesian z-coordinate in AU.
	public let z: Double
	/// The date and time at which this vector is valid.
	public let time: Date
}

extension Vector {
	/// Calculates and returns the length of the vector.
	///
	/// The length is expressed in the same units as the vector's components, usually astronomical units (AU).
	/// - returns: The length of the vector.
	public func length() -> Double {
		sqrt(x*x + y*y + z*z)
	}
}

extension Vector {
	/// Initializes `self` to the value of `vector`.
	init(_ vector: astro_vector_t) {
		precondition(vector.status == ASTRO_SUCCESS)
		x = vector.x
		y = vector.y
		z = vector.z
		time = vector.t.toDate()
	}
}

extension astro_vector_t {
	/// Converts `self` to a `Vector` instance.
	func toVector() -> Vector {
		Vector(self)
	}
}
