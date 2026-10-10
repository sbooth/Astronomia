//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension SignedInteger {
	/// Returns the quotient and remainder of this value divided by the given
	/// value using floor division.
	///
	/// The quotient and remainder are defined by the following two relations:
	/// 1. **dividend = quotient × divisor + remainder**
	/// 2. **The remainder is either zero or has the same sign as the divisor.**
	///
	/// Equivalently, the quotient is rounded toward negative infinity. This differs from
	/// Swift's `/` and `%`, which round the quotient toward zero (truncation) and give
	/// the remainder the sign of the dividend. This is the behavior of `//` and `%` in
	/// Python and of `/` and `%` in Ruby.
	///
	/// ### Example
	///
	/// ```swift
	/// (-10).quotientAndRemainder(dividingBy: 3)
	/// // (quotient: -3, remainder: -1)
	/// (-10).flooredQuotientAndRemainder(dividingBy: 3)
	/// // (quotient: -4, remainder: 2)
	/// ```
	///
	/// - Parameter divisor: The value to divide this value by.
	/// - Returns: The quotient and remainder of the division.
	/// - Precondition: `divisor` is not zero and the quotient is representable in `Self`
	///   (for a fixed-width type, this value is not `Self.min` when `divisor` is -1).
	@inlinable @inline(__always)
	func flooredQuotientAndRemainder(dividingBy divisor: Self) -> (quotient: Self, remainder: Self) {
		let (quotient, remainder) = quotientAndRemainder(dividingBy: divisor)
		if remainder != 0 && (remainder ^ divisor) < 0 {
			return (quotient - 1, remainder + divisor)
		}
		return (quotient, remainder)
	}

	/// Returns the quotient of this value divided by the given value using floor division.
	///
	/// The quotient is rounded toward negative infinity. See
	/// ``flooredQuotientAndRemainder(dividingBy:)``.
	///
	/// - Parameter divisor: The value to divide this value by.
	/// - Returns: The quotient of the division.
	/// - Precondition: `divisor` is not zero and the quotient is representable in `Self`
	///   (for a fixed-width type, this value is not `Self.min` when `divisor` is -1).
	@inlinable @inline(__always)
	func flooredQuotient(dividingBy divisor: Self) -> Self {
		flooredQuotientAndRemainder(dividingBy: divisor).quotient
	}

	/// Returns the remainder of this value divided by the given value using floor division.
	///
	/// The remainder is zero or has the same sign as the divisor. See
	/// ``flooredQuotientAndRemainder(dividingBy:)``.
	///
	/// - Parameter divisor: The value to divide this value by.
	/// - Returns: The remainder of the division.
	/// - Precondition: `divisor` is not zero, and for a fixed-width type this value is not
	///   `Self.min` when `divisor` is -1, because Swift's `%` traps on that overflow.
	@inlinable @inline(__always)
	func flooredRemainder(dividingBy divisor: Self) -> Self {
		let remainder = self % divisor
		return remainder != 0 && (remainder ^ divisor) < 0 ? remainder + divisor : remainder
	}
}
