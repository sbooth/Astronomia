//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct MathTests {
	@Test func sincosMatchesSinAndCos() {
		// Small, moderate, and large arguments, where argument reduction matters most
		var x = -1e6
		var count = 0
		while x <= 1e6 {
			for argument in [x, x / 1_000, x / 1e6] {
				let (s, c) = Math.sincos(argument)
				let (es, ec) = (Math.sin(argument), Math.cos(argument))
				// The platform's sincos may round differently from sin and cos in the last bit.
				#expect(abs(s - es) <= es.ulp && abs(c - ec) <= ec.ulp, "\(argument)")
				count += 1
			}
			x += 997.31
		}
		#expect(count > 5_000)
	}

	@Test func sincosSpecialValues() {
		#expect(Math.sincos(0) == (0, 1))
		let (s, c) = Math.sincos(-0.0)
		#expect(s == 0 && s.sign == .minus && c == 1)
		#expect(Math.sincos(.nan).sin.isNaN && Math.sincos(.nan).cos.isNaN)
		#expect(Math.sincos(.infinity).sin.isNaN && Math.sincos(.infinity).cos.isNaN)
	}
}
