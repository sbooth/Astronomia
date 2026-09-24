//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
import Foundation
import CAstronomyEngine
@testable import Astronomia

@Suite struct AstronomiaTests {
	@Test func julianDate() {
		#expect(J2000_UTC == Date.j2000.julianDate)
		#expect(-31579264.18400109 == Date.j2000.timeIntervalSinceReferenceDate)
		#expect(Date(timeIntervalSinceReferenceDate: 659005419.5984066) == Date(julianDate: 2459537.8775416482))
		// Conversion to/from astro_time_t
		#expect(Date(Astronomy_MakeTime(2000, 1, 1, 12, 0, 0)).julianDate == J2000_TT)
		let utc = Astronomy_UtcFromTime(Date.j2000.toAstroTime())
		#expect(utc.year == 2000)
		#expect(utc.month == 1)
		#expect(utc.day == 1)
		#expect(utc.hour == 11)
		#expect(utc.minute == 58)
		#expect(abs(utc.second - 55.816) < 0.001 )
	}
}
