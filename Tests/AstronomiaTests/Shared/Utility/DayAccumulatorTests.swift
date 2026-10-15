//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct DayAccumulatorTests {
	@Test func emptyAccumulator() throws {
		let acc = DayAccumulator()
		#expect(try acc.result() == (0, 0))
		#expect(try acc.flooredResult() == (0, 0))
		#expect(try DayAccumulator(days: 42).result() == (42, 0))
	}

	@Test func sumIsExact() throws {
		// The sum of ten copies of the Double nearest 0.1 exceeds 1 by 2^-54
		var acc = DayAccumulator()
		for _ in 0 ..< 10 {
			try acc.add(0.1)
		}
		#expect(try acc.result() == (1, 0x1p-54))

		// Terms far apart in magnitude are not lost
		var wide = DayAccumulator()
		try wide.add(1e15)
		try wide.add(1e-10)
		try wide.add(-1e15)
		#expect(try wide.result() == (0, 1e-10))
	}

	@Test func resultAndFlooredResult() throws {
		var acc = DayAccumulator()
		try acc.add(-0.25)
		#expect(try acc.result() == (0, -0.25))
		#expect(try acc.flooredResult() == (-1, 0.75))

		var half = DayAccumulator()
		try half.add(0.5)
		#expect(try half.result() == (1, -0.5))
		#expect(try half.flooredResult() == (0, 0.5))

		var negativeHalf = DayAccumulator()
		try negativeHalf.add(-0.5)
		#expect(try negativeHalf.result() == (0, -0.5))
		#expect(try negativeHalf.flooredResult() == (-1, 0.5))

		// A tiny negative remainder rounds up to the next midnight
		var tiny = DayAccumulator(days: 5)
		try tiny.add(-1e-20)
		#expect(try tiny.flooredResult() == (5, 0))
		#expect(try tiny.result() == (5, -1e-20))
	}

	@Test func products() throws {
		// 0.1 × 3 is 0.30000000000000004 in Double, but the accumulator keeps the error term
		var acc = DayAccumulator()
		try acc.add(product: 0.1, 3)
		try acc.add(-0.30000000000000004)
		let (days, fraction) = try acc.result()
		#expect(days == 0)
		#expect(fraction == -2.7755575615628914e-17)

		var big = DayAccumulator()
		try big.add(product: 0x1p40, 0x1p40)
		#expect(throws: DayAccumulator.Failure.overflow) { try big.result() }
	}

	@Test func seconds() throws {
		var acc = DayAccumulator()
		try acc.add(seconds: 129_600)
		#expect(try acc.result() == (2, -0.5))

		var split = DayAccumulator()
		try split.add(seconds: 86_400e6, 0.5)
		#expect(try split.result() == (1_000_000, 0.5 / 86_400))
	}

	@Test func failures() throws {
		var acc = DayAccumulator()
		#expect(throws: DayAccumulator.Failure.nonFiniteValue) { try acc.add(Double.nan) }
		#expect(throws: DayAccumulator.Failure.nonFiniteValue) { try acc.add(sum: 1, .infinity) }
		#expect(throws: DayAccumulator.Failure.nonFiniteValue) { try acc.add(product: .nan, 1) }
		#expect(throws: DayAccumulator.Failure.nonFiniteValue) { try acc.add(seconds: -.infinity) }
		#expect(throws: DayAccumulator.Failure.overflow) { try acc.add(sum: .greatestFiniteMagnitude, .greatestFiniteMagnitude) }
		#expect(throws: DayAccumulator.Failure.overflow) { try acc.add(product: .greatestFiniteMagnitude, 2) }
		#expect(throws: DayAccumulator.Failure.overflow) { try acc.add(1e300) }
		// A failed operation leaves the accumulator unchanged
		#expect(try acc.result() == (0, 0))

		// 128-bit overflow of the whole days
		var full = DayAccumulator(days: .max)
		#expect(throws: DayAccumulator.Failure.overflow) { try full.add(WideInteger(high: .max, low: .max)) }
		#expect(try full.result() == (.max, 0))
	}

	@Test func intermediateValuesMayExceedInt() throws {
		var acc = DayAccumulator(days: .max)
		try acc.add(Int.max)
		#expect(throws: DayAccumulator.Failure.overflow) { try acc.result() }
		try acc.subtract(Int.max)
		#expect(try acc.result() == (.max, 0))

		var negative = DayAccumulator(days: .min)
		try negative.subtract(Int.min)
		#expect(try negative.result() == (0, 0))
	}
}
