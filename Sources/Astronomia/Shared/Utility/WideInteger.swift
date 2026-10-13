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

	/// Creates a wide integer equal to `x`, if `x` is an integer in the range [-2^127, 2^127).
	///
	/// - Parameter x: The value to convert.
	init?(exactly x: Double) {
		guard x.isFinite, x.rounded(.towardZero) == x else { return nil }
		let magnitude = x.magnitude
		guard magnitude <= 0x1p127 else { return nil }
		// Split the magnitude into 64-bit words. Both parts are exact: the low part's bits
		// are a subset of the magnitude's 53 significant bits.
		let h = (magnitude / 0x1p64).rounded(.down)
		let l = magnitude.addingProduct(-h, 0x1p64)
		let magnitudeHigh = UInt64(h)
		let magnitudeLow = UInt64(l)
		if x < 0 {
			// Two's-complement negation; -2^127 is representable.
			let low = ~magnitudeLow &+ 1
			let high = ~magnitudeHigh &+ (low == 0 ? 1 : 0)
			self.init(high: Int64(bitPattern: high), low: low)
		} else {
			guard magnitudeHigh < 1 << 63 else { return nil }
			self.init(high: Int64(magnitudeHigh), low: magnitudeLow)
		}
	}

	/// Returns the sum of this value and `other`.
	///
	/// - Parameter other: The value to add.
	/// - Returns: The sum, or `nil` if it overflows 128 bits.
	func adding(_ other: WideInteger) -> WideInteger? {
		let (l, carry) = low.addingReportingOverflow(other.low)
		let h = high &+ other.high &+ (carry ? 1 : 0)
		// Two's-complement addition can overflow only when both operands have the same
		// sign, and overflow always flips the sign. Checking only the final sign is exact;
		// checking each step of the high-word addition would report false overflows.
		if (high ^ h) & (other.high ^ h) < 0 { return nil }
		return WideInteger(high: h, low: l)
	}

	/// Returns the sum of this value and `n`.
	///
	/// - Parameter n: The value to add.
	/// - Returns: The sum, or `nil` if it overflows 128 bits.
	func adding(_ n: Int64) -> WideInteger? {
		adding(WideInteger(n))
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
