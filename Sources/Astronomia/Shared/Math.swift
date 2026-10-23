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
		let result = astronomia_sincos(x)
		return (result.sin, result.cos)
	}

	/// Returns the arcsine of `x`, in radians in the closed interval [-π/2, π/2], or NaN if `x`
	/// is outside the closed interval [-1, 1].
	@inline(__always) static func asin(_ x: Double) -> Double { astronomia_asin(x) }

	/// Returns the arccosine of `x`, in radians in the closed interval [0, π], or NaN if `x` is
	/// outside the closed interval [-1, 1].
	@inline(__always) static func acos(_ x: Double) -> Double { astronomia_acos(x) }

	/// Returns the arctangent of `x`, in radians in the open interval (-π/2, π/2).
	@inline(__always) static func atan(_ x: Double) -> Double { astronomia_atan(x) }

	/// Returns the angle of the point (`x`, `y`) from the positive x axis, in radians in the
	/// closed interval [-π, π].
	@inline(__always) static func atan2(_ y: Double, _ x: Double) -> Double { astronomia_atan2(y, x) }

	/// Returns the natural logarithm of `x`, or NaN if `x` is negative.
	@inline(__always) static func log(_ x: Double) -> Double { astronomia_log(x) }

	/// Returns e raised to the power `x`.
	@inline(__always) static func exp(_ x: Double) -> Double { astronomia_exp(x) }

	/// Returns `x` raised to the power `y`.
	@inline(__always) static func pow(_ x: Double, _ y: Double) -> Double { astronomia_pow(x, y) }
}
