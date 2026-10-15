//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Returns `lhs - rhs` as a `Double`, rounded once.
///
/// The difference is computed exactly before conversion, so the result is the true difference
/// rounded once to the nearest `Double`. This holds even when `lhs - rhs` overflows `Int`: the
/// difference of two `Int` values is at most `UInt.max` in magnitude, which is exact in `UInt`.
///
/// Prefer this to `Double(lhs) - Double(rhs)`, which can round up to three times: once for each
/// operand above 2^53 in magnitude, and once for the subtraction. Prefer it to
/// `Double(lhs - rhs)`, which traps on overflow.
///
/// The result is exact when the difference is at most 2^53 in magnitude. On platforms where
/// `Int` is 32 bits, every difference is.
///
/// - Parameters:
///   - lhs: The minuend.
///   - rhs: The subtrahend.
/// - Returns: `lhs - rhs`, rounded to the nearest `Double`.
func differenceAsDouble(_ lhs: Int, _ rhs: Int) -> Double {
	let (difference, overflow) = lhs.subtractingReportingOverflow(rhs)
	guard overflow else { return Double(difference) }
	// Overflow means the operands have opposite signs, so the result is ±(|lhs| + |rhs|) with the
	// sign of lhs. The magnitude is at most UInt.max, exact in UInt, and converts with one
	// rounding. Converting each operand to Double first could round up to three times.
	if lhs >= 0 {
		return Double(lhs.magnitude + rhs.magnitude)
	}
	return -Double(lhs.magnitude + rhs.magnitude)
}
