//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// An ephemeris of the Earth on a circular orbit about a fixed Sun, in the plane of the
/// ICRS's equator, covering 10,000 years either side of J2000.0, wider than the built-in one,
/// with a Moon that keeps 45° from the Sun, so it never reaches a phase.
struct CircularEphemeris: GeocentricEphemeris {
	/// The bodies, all points.
	enum Body: EphemerisBody {
		case solarSystemBarycenter, sun, earth, moon

		var radius: Distance? { nil }
	}

	typealias Frame = ICRS

	static let defaultOrigin = Body.solarSystemBarycenter
	static let earth = Body.earth
	static let sun = Body.sun
	static let solarSystemBarycenter = Body.solarSystemBarycenter
	static let lightDeflectingBodies: [LightDeflectingBody<Body>] = []

	/// The phase of the orbit at J2000.0, in radians.
	var phase = 0.0

	var coverage: ClosedRange<Instant<TDB>> {
		let days = 10_000 * daysPerJulianYear
		return Instant(JulianDate(uncheckedJulianDayNumber: 2_451_545 - Int(days), fractionFromNoon: 0)) ... Instant(JulianDate(uncheckedJulianDayNumber: 2_451_545 + Int(days), fractionFromNoon: 0))
	}

	func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
		guard coverage.contains(tdb) else { throw .outsideCoverage }
		func heliocentric(_ body: Body) -> (position: Vector3, velocity: Vector3) {
			guard body != .sun, body != .solarSystemBarycenter else { return (.zero, .zero) }
			let rate = twoPi / 365.256_363
			let (s, c) = Math.sincos(phase + rate * tdb.julianDate.daysSinceJ2000)
			let earth = (position: Vector3(c, s, 0), velocity: Vector3(-s, c, 0) * rate)
			guard body == .moon else { return earth }
			// The Sun's direction from the Earth, turned 45° east, at the Moon's distance
			let (s45, c45) = Math.sincos(Double.pi / 4)
			let distance = 0.002_57
			let turned = Vector3(-(c * c45 - s * s45), -(c * s45 + s * c45), 0)
			let rotating = Vector3(-turned.y, turned.x, 0) * rate
			return (earth.position + turned * distance, earth.velocity + rotating * distance)
		}
		let (a, b) = (heliocentric(body), heliocentric(origin))
		return StateVector(a.position - b.position, a.velocity - b.velocity)
	}
}

/// An ephemeris whose coverage ends early, at an instant within another's.
struct TruncatedEphemeris<Base: GeocentricEphemeris>: GeocentricEphemeris {
	typealias Body = Base.Body
	typealias Frame = Base.Frame

	static var defaultOrigin: Body { Base.defaultOrigin }
	static var earth: Body { Base.earth }
	static var sun: Body { Base.sun }
	static var solarSystemBarycenter: Body { Base.solarSystemBarycenter }
	static var lightDeflectingBodies: [LightDeflectingBody<Body>] { Base.lightDeflectingBodies }

	let base: Base
	/// The end of the coverage.
	let end: Instant<TDB>

	/// Creates an ephemeris whose coverage ends at an instant in TT.
	init(_ base: Base, endingAt end: Instant<TT>) throws {
		self.base = base
		self.end = try end.converted(to: TDB.self)
	}

	var coverage: ClosedRange<Instant<TDB>> { base.coverage.lowerBound ... end }

	func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<Frame> {
		guard coverage.contains(tdb) else { throw .outsideCoverage }
		return try base.state(of: body, relativeTo: origin, at: tdb)
	}
}

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

	@Test func yearAtTheEndOfTheCoverage() throws {
		// The December solstice of the Julian year 2999 is within the coverage, though the year,
		// and the search's window, end 12 days past it; the search stops at the solstice.
		let julian = try Seasons.instant(of: .decemberSolstice, year: 2999, calendar: .julian, precision: .arcsecond)
		let gregorian = try Seasons.instant(of: .decemberSolstice, year: 2999, calendar: .gregorian, precision: .arcsecond)
		#expect(abs(Self.julianDate(julian) - Self.julianDate(gregorian)) * secondsPerDay < 0.1)
		// The full search still reaches the end of the interval it was given.
		#expect(throws: SeasonError.ephemeris(.outsideCoverage)) {
			try Seasons.events(from: julian, to: Instant<TT>(try JulianDate(year: 3000, month: 1, day: 1, calendar: .julian)), precision: .arcsecond)
		}
	}

	@Test func eventAtTheEndOfTheCoverage() throws {
		// An event 15 minutes before the end of the coverage is found, though the bracket the
		// search predicts runs days past it.
		let june = try Seasons.instant(of: .juneSolstice, year: 2026, precision: .arcsecond)
		let ephemeris = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try june.julianDate.adding(seconds: 900)))
		let found = try Seasons.instant(of: .juneSolstice, year: 2026, ephemeris: ephemeris)
		#expect(abs(Self.julianDate(found) - Self.julianDate(june)) * secondsPerDay < 0.1)
		let start = Instant<TT>(try june.julianDate.adding(days: -100))
		let events = try Seasons.events(from: start, to: Instant<TT>(try june.julianDate.adding(seconds: 600)), ephemeris: ephemeris)
		#expect(events.map(\.kind) == [.marchEquinox, .juneSolstice])
		#expect(abs(Self.julianDate(try #require(events.last).instant) - Self.julianDate(june)) * secondsPerDay < 0.1)
		// An event past the end isn't.
		#expect(throws: SeasonError.ephemeris(.outsideCoverage)) { try Seasons.instant(of: .septemberEquinox, year: 2026, ephemeris: ephemeris) }
		let early = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try june.julianDate.adding(seconds: -900)))
		#expect(throws: SeasonError.ephemeris(.outsideCoverage)) { try Seasons.instant(of: .juneSolstice, year: 2026, ephemeris: early) }
	}

	@Test func yearsOfAWiderEphemeris() throws {
		// The search for a year assumes nothing of the coverage or of the calendar's drift: in
		// an ephemeris covering 10,000 years either side of J2000.0, each event of a year is
		// the one that the full search of the year finds, wherever it falls in the year, or
		// is missing from a year that the full search finds without one.
		var missing = 0
		for phase in stride(from: 0.0, to: twoPi, by: twoPi / 7) {
			let ephemeris = CircularEphemeris(phase: phase)
			for (year, calendar) in [(6000, CalendarIdentifier.gregorian), (6000, .julian), (-3000, .julian), (-3000, .gregorian), (2026, .gregorian)] {
				let start = Instant<TT>(try JulianDate(year: year, month: 1, day: 1, calendar: calendar))
				let end = Instant<TT>(try JulianDate(year: year + 1, month: 1, day: 1, calendar: calendar))
				let all = try Seasons.events(from: start, to: end, ephemeris: ephemeris)
				for kind in SeasonEvent.Kind.allCases {
					let comment = Comment(rawValue: "\(kind) in \(year), \(calendar), phase \(phase)")
					if let expected = all.first(where: { $0.kind == kind }) {
						let instant = try Seasons.instant(of: kind, year: year, calendar: calendar, ephemeris: ephemeris)
						#expect(abs(Self.julianDate(instant) - Self.julianDate(expected.instant)) * secondsPerDay < 0.1, comment)
					} else {
						missing += 1
						#expect(throws: SeasonError.eventNotInYear, comment) { try Seasons.instant(of: kind, year: year, calendar: calendar, ephemeris: ephemeris) }
					}
				}
			}
		}
		// A year without an event is rare.
		#expect(missing < 5)
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
