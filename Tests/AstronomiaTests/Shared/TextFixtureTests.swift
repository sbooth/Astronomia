//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct TextFixtureTests {
	static func rows(_ text: String) -> [(whole: Double, kind: Moon.PhaseEvent.Kind, value: Double?)] {
		textFixture("Test", text: text) { row in
			(row.double(), row.value(), row.optionalDouble())
		}
	}

	@Test func lineEndings() {
		// The rows are the same whatever ends the lines, and comments and empty lines are skipped.
		let lines = ["# whole kind value", "", "2451550.0 newMoon 0.25", "2451558.0 firstQuarter nil"]
		for newline in ["\n", "\r\n", "\r"] {
			for end in ["", newline] {
				let rows = Self.rows(lines.joined(separator: newline) + end)
				#expect(rows.count == 2, "\(Array(newline.unicodeScalars))")
				#expect(rows.first?.whole == 2_451_550 && rows.first?.kind == .newMoon && rows.first?.value == 0.25)
				#expect(rows.last?.whole == 2_451_558 && rows.last?.kind == .firstQuarter && rows.last?.value == nil)
			}
		}
	}

	@Test func fixturesHaveRows() {
		#expect(skyfieldMoonPhases.count == 2_474)
		#expect(nasaLunarEclipses.count == 112)
		#expect(skyfieldRiseTransitSetEvents.count == 135)
		#expect(vsop2013CheckValues.count == 99)
		#expect(elpmpp02CheckValues.count == 36 && elpmpp02Reference.count == 24)
		#expect(de421States.count == 96)
		#expect(skyfieldPlaces.count == 100)
		#expect(erfaIAU2006.count == 26)
	}
}
