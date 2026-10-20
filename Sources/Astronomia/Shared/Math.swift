//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaMath

/// Elementary functions from the platform's C math library.
enum Math {
	/// Returns the sine of `x`, in radians.
	@inline(__always) static func sin(_ x: Double) -> Double { astronomia_sin(x) }

	/// Returns the cosine of `x`, in radians.
	@inline(__always) static func cos(_ x: Double) -> Double { astronomia_cos(x) }

	/// Returns the tangent of `x`, in radians.
	@inline(__always) static func tan(_ x: Double) -> Double { astronomia_tan(x) }

	/// Returns the sine and cosine of `x`, in radians.
	@inline(__always) static func sincos(_ x: Double) -> (sin: Double, cos: Double) {
		var s: Double = 0
		var c: Double = 0
		astronomia_sincos(x, &s, &c)
		return (s, c)
	}

	/// Returns the arcsine of `x`, in radians in [-π/2, π/2], or NaN if `x` is outside [-1, 1].
	@inline(__always) static func asin(_ x: Double) -> Double { astronomia_asin(x) }

	/// Returns the arccosine of `x`, in radians in [0, π], or NaN if `x` is outside [-1, 1].
	@inline(__always) static func acos(_ x: Double) -> Double { astronomia_acos(x) }

	/// Returns the arctangent of `x`, in radians in (-π/2, π/2).
	@inline(__always) static func atan(_ x: Double) -> Double { astronomia_atan(x) }

	/// Returns the angle of the point (`x`, `y`) from the positive x axis, in radians in
	/// [-π, π].
	@inline(__always) static func atan2(_ y: Double, _ x: Double) -> Double { astronomia_atan2(y, x) }
}
