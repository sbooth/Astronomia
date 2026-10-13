//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A signed 128-bit integer stored as two 64-bit words in two's complement.
struct WideInteger: Hashable {
	/// The high word, which carries the sign.
	let high: Int64
	/// The low word.
	let low: UInt64

	/// Creates a wide integer equal to zero.
	init() {
		self.init(high: 0, low: 0)
	}

	/// Creates a wide integer from its two's-complement words.
	///
	/// - Parameters:
	///   - high: The high word, which carries the sign.
	///   - low: The low word.
	init(high: Int64, low: UInt64) {
		self.high = high
		self.low = low
	}

	/// Creates a wide integer equal to `n`.
	///
	/// - Parameter n: The initial value.
	init(_ n: Int64) {
		self.init(high: n >> 63, low: UInt64(bitPattern: n))
	}

	/// Creates a wide integer equal to `n`.
	///
	/// - Parameter n: The initial value.
	init(_ n: Int) {
		self.init(Int64(n))
	}

	/// Returns the sum of this value and `n`.
	///
	/// - Parameter n: The value to add.
	/// - Returns: The sum, or `nil` if it overflows 128 bits.
	func adding(_ n: Int64) -> WideInteger? {
		let (newLow, carry) = low.addingReportingOverflow(UInt64(bitPattern: n))
		let newHigh = high &+ (n < 0 ? -1 : 0) &+ (carry ? 1 : 0)
		// Two's-complement addition can overflow only when both operands have the same
		// sign, and overflow always flips the sign. Checking only the final sign is exact;
		// checking each step of the high-word addition would report false overflows.
		if (high < 0) == (n < 0) && (newHigh < 0) != (high < 0) { return nil }
		return WideInteger(high: newHigh, low: newLow)
	}

	/// Returns the sum of this value and `n`.
	///
	/// - Parameter n: The value to add.
	/// - Returns: The sum, or `nil` if it overflows 128 bits.
	func adding(_ n: Int) -> WideInteger? {
		adding(Int64(n))
	}

	/// This value as an `Int`, or `nil` if it cannot be represented as one.
	var intValue: Int? {
		// The value fits in 64 bits exactly when the high word is the sign extension of the low word.
		guard high == Int64(bitPattern: low) >> 63 else { return nil }
		return Int(exactly: Int64(bitPattern: low))
	}
}
