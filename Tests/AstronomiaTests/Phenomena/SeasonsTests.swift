//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct SeasonsTests {
	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the difference from a Skyfield event, in seconds.
	static func difference(_ instant: Instant<TT>, _ expected: (whole: Double, fraction: Double, kind: SeasonEvent.Kind)) -> Double {
		abs((julianDate(instant) - expected.whole) - expected.fraction) * secondsPerDay
	}

	@Test func matchesSkyfield() throws {
		// Two years of events at full precision, within 0.1 s of Skyfield's with DE421
		let start = Instant<TT>(try JulianDate(julianDate: 2_460_676.5))
		let end = Instant<TT>(try JulianDate(julianDate: 2_461_406.5))
		let events = try Seasons.events(from: start, to: end)
		let expected = skyfieldSeasons.filter { $0.whole + $0.fraction > 2_460_676.5 && $0.whole + $0.fraction < 2_461_406.5 }
		#expect(events.count == 8 && expected.count == 8)
		for (event, expected) in zip(events, expected) {
			#expect(event.kind == expected.kind)
			#expect(Self.difference(event.instant, expected) <= 0.15, "\(event.kind) \(expected)")
		}
		// The rest of the span, an event each quarter century, at 0.1"
		for (index, expected) in skyfieldSeasons.enumerated() where index % 100 == 37 {
			let year = Int(((expected.whole + expected.fraction - 2_451_545) / daysPerJulianYear + 2000).rounded(.down))
			let instant = try Seasons.instant(of: expected.kind, year: year, precision: .tenthArcsecond)
			#expect(Self.difference(instant, expected) <= 0.25, "\(expected)")
		}
	}

	@Test func sunIsAtTheLongitude() throws {
		// At each event the Sun's apparent longitude is the event's, within its motion over
		// 0.1 s, about 0.004"
		for kind in SeasonEvent.Kind.allCases {
			let instant = try Seasons.instant(of: kind, year: 2026, precision: .tenthArcsecond)
			let sky = try Observer.geocenter.observation(at: instant, ephemeris: BuiltInEphemeris(precision: .tenthArcsecond))
			let longitude = try sky.apparentPlace(of: .sun, in: TrueEclipticOfDate.self).position.spherical.longitude
			let difference = (longitude.radians - kind.longitude.radians).remainder(dividingBy: twoPi)
			#expect(abs(difference) <= Angle(arcseconds: 0.01).radians, "\(kind)")
		}
		#expect(SeasonEvent.Kind.allCases.map(\.longitude.degrees) == [0, 90, 180, 270])
	}

	@Test func years() throws {
		// The events of a year are in order, about a quarter of a year apart, at the ends of the
		// coverage and across the Gregorian reform.
		for year in [1000, 1582, 1583, 2999] {
			let instants = try SeasonEvent.Kind.allCases.map { try Seasons.instant(of: $0, year: year, precision: .arcsecond) }
			let days = zip(instants, instants.dropFirst()).map { Self.julianDate($1) - Self.julianDate($0) }
			#expect(days.allSatisfy { $0 > 88 && $0 < 95 }, "\(year): \(days)")
			#expect(instants[0].julianDate.calendarDate.year == year)
		}
		// The 2026 June solstice, 2026-06-21 08:24 UTC
		let june = try Seasons.instant(of: .juneSolstice, year: 2026, precision: .tenthArcsecond)
		let utc = try june.converted(to: UTC.self).julianDate.calendarDate
		#expect(utc.year == 2026 && utc.month == 6 && utc.day == 21)
		let minutes = utc.fractionSinceMidnight * 24 * 60
		#expect(minutes > 8 * 60 + 24 && minutes < 8 * 60 + 25)
		// The calendar matters only for the year's bounds: in 1500 the Julian and Gregorian
		// years hold the same event, found from searches that start on different days.
		let julian = try Seasons.instant(of: .juneSolstice, year: 1500, calendar: .julian, precision: .arcsecond)
		let gregorian = try Seasons.instant(of: .juneSolstice, year: 1500, calendar: .gregorian, precision: .arcsecond)
		#expect(abs(Self.julianDate(julian) - Self.julianDate(gregorian)) * secondsPerDay < 0.1)
		// Beyond the coverage
		#expect(throws: SeasonError.ephemeris(.outsideCoverage)) { try Seasons.instant(of: .marchEquinox, year: 3000, precision: .arcsecond) }
		#expect(throws: SeasonError.ephemeris(.outsideCoverage)) { try Seasons.instant(of: .decemberSolstice, year: 999, precision: .arcsecond) }
		#expect(throws: SeasonError.invalidYear) { try Seasons.instant(of: .marchEquinox, year: .max, precision: .arcsecond) }
	}

	@Test func intervals() throws {
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		// An empty interval, and one that ends before it starts
		#expect(try Seasons.events(from: start, to: start, precision: .arcsecond).isEmpty)
		#expect(throws: SeasonError.invalidInterval) { try Seasons.events(from: start, to: Instant<TT>(try JulianDate(julianDate: 2_461_041.4))) }
		// An interval just around one event finds it, and one just before or after doesn't.
		let march = try Seasons.instant(of: .marchEquinox, year: 2026, precision: .arcsecond)
		let before = Instant<TT>(try march.julianDate.adding(seconds: -60))
		let after = Instant<TT>(try march.julianDate.adding(seconds: 60))
		#expect(try Seasons.events(from: before, to: after, precision: .arcsecond).map(\.kind) == [.marchEquinox])
		#expect(try Seasons.events(from: Instant<TT>(try before.julianDate.adding(days: -20)), to: before, precision: .arcsecond).isEmpty)
		#expect(try Seasons.events(from: after, to: Instant<TT>(try after.julianDate.adding(days: 20)), precision: .arcsecond).isEmpty)
		// An interval in UTC
		let utcStart = try start.converted(to: UTC.self)
		let utcEnd = try Instant<TT>(try JulianDate(julianDate: 2_461_406.5)).converted(to: UTC.self)
		#expect(try Seasons.events(from: utcStart, to: utcEnd, precision: .arcsecond).map(\.kind) == SeasonEvent.Kind.allCases)
	}
}
