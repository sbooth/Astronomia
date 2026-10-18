//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(ucrt)
import ucrt
#endif

/// Elementary functions from the platform's C math library.
///
/// This is the only file that imports the platform module, so the rest of the library calls
/// these and needs no conditional imports. A qualified call such as `Math.sin(x)` is also
/// unambiguous in a type with a member of the same name, such as ``Angle/sin``.
enum Math {
	/// Returns the sine of `x`, in radians.
	@inline(__always) static func sin(_ x: Double) -> Double { libm_sin(x) }

	/// Returns the cosine of `x`, in radians.
	@inline(__always) static func cos(_ x: Double) -> Double { libm_cos(x) }

	/// Returns the tangent of `x`, in radians.
	@inline(__always) static func tan(_ x: Double) -> Double { libm_tan(x) }

	/// Returns the sine and cosine of `x`, in radians.
	@inline(__always) static func sincos(_ x: Double) -> (sin: Double, cos: Double) { (libm_sin(x), libm_cos(x)) }

	/// Returns the arcsine of `x`, in radians in [-π/2, π/2], or NaN if `x` is outside [-1, 1].
	@inline(__always) static func asin(_ x: Double) -> Double { libm_asin(x) }

	/// Returns the arccosine of `x`, in radians in [0, π], or NaN if `x` is outside [-1, 1].
	@inline(__always) static func acos(_ x: Double) -> Double { libm_acos(x) }

	/// Returns the arctangent of `x`, in radians in (-π/2, π/2).
	@inline(__always) static func atan(_ x: Double) -> Double { libm_atan(x) }

	/// Returns the angle of the point (`x`, `y`) from the positive x axis, in radians in
	/// [-π, π].
	@inline(__always) static func atan2(_ y: Double, _ x: Double) -> Double { libm_atan2(y, x) }
}

@inline(__always) private func libm_sin(_ x: Double) -> Double { sin(x) }
@inline(__always) private func libm_cos(_ x: Double) -> Double { cos(x) }
@inline(__always) private func libm_tan(_ x: Double) -> Double { tan(x) }
@inline(__always) private func libm_asin(_ x: Double) -> Double { asin(x) }
@inline(__always) private func libm_acos(_ x: Double) -> Double { acos(x) }
@inline(__always) private func libm_atan(_ x: Double) -> Double { atan(x) }
@inline(__always) private func libm_atan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) }
