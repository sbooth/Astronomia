//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import Testing
@testable import Astronomia

@Suite struct DistanceTests {
	@Test func units() {
		let au = Distance(astronomicalUnits: 1)
		#expect(au.meters == 149_597_870_700)
		#expect(au.kilometers == 149_597_870.7)
		#expect(Distance(meters: 149_597_870_700).astronomicalUnits == 1)
		#expect(abs(Distance(kilometers: 384_400).astronomicalUnits - 0.002_569_555_289_799_990_7) <= 1e-18)
		#expect(abs(Distance(kilometers: 1).kilometers - 1) <= 1e-15)
	}

	@Test func arithmetic() {
		let a = Distance(astronomicalUnits: 1.5)
		let b = Distance(astronomicalUnits: 0.5)
		#expect(a + b == Distance(astronomicalUnits: 2))
		#expect(a - b == Distance(astronomicalUnits: 1))
		#expect(-a == Distance(astronomicalUnits: -1.5))
		#expect(a * 2 == Distance(astronomicalUnits: 3))
		#expect(2 * a == Distance(astronomicalUnits: 3))
		#expect(a / 3 == Distance(astronomicalUnits: 0.5))
		#expect(a / b == 3)
		#expect((-a).magnitude == a)
		#expect(b < a)
		#expect(Distance.zero == Distance(astronomicalUnits: 0))

		var c = a
		c *= 2
		c /= 4
		#expect(c == Distance(astronomicalUnits: 0.75))
	}

	@Test func description() {
		#expect(Distance(astronomicalUnits: 1).description == "1.0 au")
	}

	@Test func codable() throws {
		let distance = Distance(astronomicalUnits: 5.2)
		let data = try JSONEncoder().encode(distance)
		#expect(String(decoding: data, as: UTF8.self) == "5.2")
		#expect(try JSONDecoder().decode(Distance.self, from: data) == distance)
	}
}
