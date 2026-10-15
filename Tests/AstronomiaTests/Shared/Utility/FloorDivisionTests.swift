//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct FloorDivisionTests {
	@Test func flooredQuotientAndRemainder() {
		let cases: [(dividend: Int, divisor: Int, quotient: Int, remainder: Int)] = [
			(7, 2, 3, 1),
			(-7, 2, -4, 1),
			(7, -2, -4, -1),
			(-7, -2, 3, -1),
			(-8, 2, -4, 0),
			(0, 5, 0, 0),
			(-1, 532, -1, 531),
			(Int.min, 12, -768_614_336_404_564_651, 4),
			(Int.max, 400, 23_058_430_092_136_939, 207),
		]
		for c in cases {
			#expect(c.dividend.flooredQuotientAndRemainder(dividingBy: c.divisor) == (c.quotient, c.remainder), "\(c.dividend) / \(c.divisor)")
			#expect(c.dividend.flooredQuotient(dividingBy: c.divisor) == c.quotient)
			#expect(c.dividend.flooredRemainder(dividingBy: c.divisor) == c.remainder)
			// The identity holds modulo 2^64 even when the product overflows
			#expect(c.quotient &* c.divisor &+ c.remainder == c.dividend)
		}
	}

	@Test func remainderHasSignOfDivisor() {
		for dividend in -50 ... 50 {
			for divisor in [-7, -3, 3, 7] {
				let (q, r) = dividend.flooredQuotientAndRemainder(dividingBy: divisor)
				#expect(q * divisor + r == dividend)
				#expect(r == 0 || (r > 0) == (divisor > 0))
				#expect(r.magnitude < divisor.magnitude)
			}
		}
	}
}
