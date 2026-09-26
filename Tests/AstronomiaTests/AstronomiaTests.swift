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
	@Test func j2000() {
		#expect(Date.j2000.timeIntervalSinceReferenceDate == -31579264.184)
		#expect(Date.j2000.timeIntervalSinceJ2000 == 0)
		#expect(Date(timeIntervalSinceJ2000: 0) == Date.j2000)
		#expect(Date.j2000.daysSinceJ2000 == 0)
		#expect(Date(daysSinceJ2000: 0) == Date.j2000)
	}

	@Test func jd() {
		#expect(Date.j2000.timeIntervalSinceReferenceDate - Date(julianDate: 2451544.9992571296).timeIntervalSinceReferenceDate < 0.001)
		#expect(Date(julianDate: 2451544.9992571296).daysSinceJ2000 < 1e-10)
	}

	@Test func astroTime() {
		let d1 = Date(Astronomy_MakeTime(2000, 1, 1, 12, 0, 0))
		#expect(d1.timeIntervalSinceReferenceDate - 64.184 < 0.001)
		let utc = Astronomy_UtcFromTime(Date.j2000.toAstroTime())
		#expect(utc.year == 2000)
		#expect(utc.month == 1)
		#expect(utc.day == 1)
		#expect(utc.hour == 11)
		#expect(utc.minute == 58)
		#expect(utc.second - 55.816 < 0.001 )
	}
}
