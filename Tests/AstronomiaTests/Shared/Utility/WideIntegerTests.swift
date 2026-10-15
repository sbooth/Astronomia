//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct WideIntegerTests {
	@Test func initFromInt() {
		#expect(WideInteger(0) == WideInteger())
		#expect(WideInteger(5) == WideInteger(high: 0, low: 5))
		#expect(WideInteger(-1) == WideInteger(high: -1, low: .max))
		#expect(WideInteger(Int.min) == WideInteger(high: -1, low: 1 << 63))
		#expect(WideInteger(Int.max) == WideInteger(high: 0, low: UInt64(Int64.max)))
	}

	@Test func intValue() {
		for n in [Int.min, -1, 0, 1, Int.max] {
			#expect(WideInteger(n).intValue == n)
		}
		#expect(WideInteger(high: 0, low: 1 << 63).intValue == nil)
		#expect(WideInteger(high: -1, low: 0).intValue == nil)
		#expect(WideInteger(high: 1, low: 0).intValue == nil)
	}

	@Test func adding() {
		#expect(WideInteger(2).adding(3)?.intValue == 5)
		#expect(WideInteger(-2).adding(-3)?.intValue == -5)
		// Carry from the low word into the high word
		#expect(WideInteger(Int.max).adding(1) == WideInteger(high: 0, low: 1 << 63))
		#expect(WideInteger(high: 0, low: .max).adding(1) == WideInteger(high: 1, low: 0))
		#expect(WideInteger(Int.min).adding(-1) == WideInteger(high: -1, low: (1 << 63) - 1))
		#expect(WideInteger(Int.max).adding(WideInteger(Int.max))?.intValue == nil)
		#expect(WideInteger(Int.max).adding(Int.min)?.intValue == -1)
		// 128-bit overflow
		#expect(WideInteger(high: .max, low: .max).adding(1) == nil)
		#expect(WideInteger(high: .min, low: 0).adding(-1) == nil)
		#expect(WideInteger(high: .max, low: .max).adding(WideInteger(high: .min, low: 0)) == WideInteger(-1))
	}

	@Test func negated() {
		#expect(WideInteger(5).negated()?.intValue == -5)
		#expect(WideInteger(0).negated() == WideInteger(0))
		#expect(WideInteger(Int.min).negated() == WideInteger(high: 0, low: 1 << 63))
		#expect(WideInteger(high: 1, low: 0).negated() == WideInteger(high: -1, low: 0))
		#expect(WideInteger(high: .max, low: .max).negated() == WideInteger(high: .min, low: 1))
		#expect(WideInteger(high: .min, low: 0).negated() == nil)
	}

	@Test func initFromDouble() {
		#expect(WideInteger(exactly: 0.0) == WideInteger(0))
		#expect(WideInteger(exactly: -0.0) == WideInteger(0))
		#expect(WideInteger(exactly: 42.0) == WideInteger(42))
		#expect(WideInteger(exactly: -3.0) == WideInteger(-3))
		#expect(WideInteger(exactly: 0x1p63) == WideInteger(high: 0, low: 1 << 63))
		#expect(WideInteger(exactly: -0x1p63) == WideInteger(Int.min))
		#expect(WideInteger(exactly: 0x1p64) == WideInteger(high: 1, low: 0))
		#expect(WideInteger(exactly: -0x1p64) == WideInteger(high: -1, low: 0))
		#expect(WideInteger(exactly: 0x1p64 + 0x1p12) == WideInteger(high: 1, low: 1 << 12))
		#expect(WideInteger(exactly: -0x1p127) == WideInteger(high: .min, low: 0))
		#expect(WideInteger(exactly: 0x1p127.nextDown) == WideInteger(high: .max - (1 << 10) + 1, low: 0))

		#expect(WideInteger(exactly: 0x1p127) == nil)
		#expect(WideInteger(exactly: 1e300) == nil)
		#expect(WideInteger(exactly: 0.5) == nil)
		#expect(WideInteger(exactly: -1.5) == nil)
		#expect(WideInteger(exactly: .nan) == nil)
		#expect(WideInteger(exactly: .infinity) == nil)
		#expect(WideInteger(exactly: -.infinity) == nil)
	}
}
