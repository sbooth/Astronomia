//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct RiseTransitSetTests {
	/// UT1 = TT - 69.2 s, as in the fixtures.
	static let earthOrientation = EarthOrientation(ut1: UT1.Context(deltaT: DeltaTFunction.constant(69.2)))

	static func site(_ index: Int) throws -> Observer {
		let s = riseTransitSetSites[index]
		return try Observer.site(latitude: .degrees(s.latitude), longitude: .degrees(s.longitude), height: .meters(s.height))
	}

	static func star(_ index: Int) throws -> Star {
		let d = riseTransitSetStars[index]
		return try Star(rightAscension: .degrees(d.rightAscension), declination: .degrees(d.declination), properMotionInRightAscension: .milliarcseconds(d.properMotionInRightAscension), properMotionInDeclination: .milliarcseconds(d.properMotionInDeclination), parallax: .milliarcseconds(d.parallax), radialVelocity: .kilometersPerSecond(d.radialVelocity), epoch: Instant(try JulianDate(julianEpoch: d.epoch)))
	}

	static func instant(_ julianDate: Double) throws -> Instant<TT> {
		Instant(try JulianDate(julianDate: julianDate))
	}

	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the events of a fixture's target from a site.
	static func events(_ site: Observer, _ target: RiseTransitSetTarget, from start: Instant<TT>, to end: Instant<TT>, altitude: EventAltitude, precision: Precision = .arcsecond) throws -> [RiseTransitSetEvent] {
		switch target {
		case let .body(body):
			try site.riseTransitSetEvents(of: body, from: start, to: end, altitude: altitude, earthOrientation: earthOrientation, precision: precision)
		case let .star(index):
			try site.riseTransitSetEvents(of: star(index), from: start, to: end, altitude: altitude, earthOrientation: earthOrientation, precision: precision)
		}
	}

	/// Expects the events of the first day of each fixture from a site to match Skyfield's:
	/// every event in either is in the other, within a tolerance, away from the ends of the day.
	static func expectMatchesSkyfield(site index: Int, precision: Precision, tolerance: Double) throws {
		let site = try Self.site(index)
		for row in skyfieldRiseTransitSetEvents where row.site == index {
			let altitude = try row.centerAltitude.map { try EventAltitude.center(altitude: .arcminutes($0)) } ?? .standard
			let events = try Self.events(site, row.target, from: Self.instant(row.start), to: Self.instant(row.start + 1), altitude: altitude, precision: precision)
				.filter { $0.kind != .lowerTransit && (row.hasTransits || $0.kind != .upperTransit) }
			let inside = { (julianDate: Double) in julianDate > row.start + 0.001 && julianDate < row.start + 0.999 }
			let comment = Comment(rawValue: "\(row.target) at \(row.centerAltitude.map { "\($0)'" } ?? "standard") from \(riseTransitSetSites[index].name) at \(row.start), \(precision)")
			for event in events where inside(Self.julianDate(event.instant)) {
				let nearest = row.events.filter { $0.kind == event.kind }.map { abs($0.julianDate - Self.julianDate(event.instant)) * secondsPerDay }.min() ?? .infinity
				#expect(nearest <= tolerance, comment)
			}
			for expected in row.events where inside(expected.julianDate) {
				#expect(events.contains { $0.kind == expected.kind && abs(Self.julianDate($0.instant) - expected.julianDate) * secondsPerDay <= tolerance }, comment)
			}
		}
	}

	@Test(arguments: riseTransitSetSites.indices)
	func matchesSkyfield(site index: Int) throws {
		// Every site at the coarsest precision, whose 10" moves an event by under 0.5 s
		try Self.expectMatchesSkyfield(site: index, precision: .tenArcseconds, tolerance: 0.6)
	}

	@Test func matchesSkyfieldAtTheDefaultPrecision() throws {
		// Greenwich at the default precision, within 0.1 s of Skyfield's at full precision
		try Self.expectMatchesSkyfield(site: 0, precision: .arcsecond, tolerance: 0.15)
	}

	/// A search for a target at a constant declination from a latitude, turning with the sky,
	/// whose event altitude is its altitude some seconds after upper transit.
	static func constantDeclinationSearch(declination: Double, latitude: Double, secondsAfterTransit: Double, length: Double) -> RiseTransitSetSearch {
		let rate = twoPi * 1.002_737_909
		func altitude(_ days: Double) -> Double {
			Math.asin(Math.sin(latitude) * Math.sin(declination) + Math.cos(latitude) * Math.cos(declination) * Math.cos(rate * days))
		}
		let threshold = altitude(secondsAfterTransit / secondsPerDay)
		return RiseTransitSetSearch(length: length) { (days: Double) throws(RiseTransitSetError) -> RiseTransitSetSearch.Sample in
			let instant = Instant<TT>(JulianDate.j2000)
			let place = ObservedPlace(azimuth: .zero, altitude: Angle(radians: altitude(days)), hourAngle: Angle(radians: RiseTransitSetSearch.reduced(rate * days)), declination: Angle(radians: declination), parallacticAngle: .zero, distance: .astronomicalUnits(1), instant: instant)
			return RiseTransitSetSearch.Sample(time: days, instant: instant, hourAngle: place.hourAngle.radians, height: altitude(days) - threshold, place: place)
		}
	}

	@Test func crossingNearTransit() throws {
		// Near transit the altitude barely changes, so the estimates of false position creep
		// toward the crossing; they once stopped 10 s early, when two came within 0.1 s.
		let latitude = Angle(degrees: 51.4769).radians
		let declination = Angle(degrees: 20).radians
		for seconds in [0.5, 10.0, 60, 600] {
			let search = Self.constantDeclinationSearch(declination: declination, latitude: latitude, secondsAfterTransit: seconds, length: 1)
			let crossing = try search.refine(search.evaluate(0), search.evaluate(1.0 / 24)) { $0.height }
			#expect(abs(crossing.time * secondsPerDay - seconds) <= 0.1, "\(seconds) s")
			// The full search finds the setting there too.
			let setting = try #require(try search.events().first { $0.kind == .set })
			#expect(abs(setting.place.altitude.radians - crossing.place.altitude.radians) <= 1e-9)
		}
	}

	@Test func eventsAreWhereTheyShouldBe() throws {
		// At each rising and setting the upper limb is at -34', and at each transit the hour
		// angle is 0° or 180°, within the motion of 0.1 s, about 1.5".
		let site = try Self.site(0)
		let start = try Self.instant(2_461_211.5)
		let events = try site.riseTransitSetEvents(of: .moon, from: start, to: Self.instant(2_461_213.5), earthOrientation: Self.earthOrientation)
		#expect(Set(events.map(\.kind)) == Set(RiseTransitSetEvent.Kind.allCases))
		#expect(events.map(\.instant) == events.map(\.instant).sorted())
		let tolerance = Angle(arcseconds: 2).radians
		for event in events {
			let place = event.place
			#expect(place.instant == event.instant)
			switch event.kind {
			case .rise, .set:
				let semidiameter = Math.asin(lunarMeanRadius.astronomicalUnits / place.distance.astronomicalUnits)
				#expect(abs(place.altitude.radians + semidiameter + Angle(arcminutes: 34).radians) <= tolerance)
				// Rising in the east, setting in the west
				#expect((event.kind == .rise) == (place.azimuth.degrees < 180))
			case .upperTransit:
				#expect(abs(place.hourAngle.radians) <= tolerance)
			case .lowerTransit:
				#expect(abs(abs(place.hourAngle.radians) - .pi) <= tolerance)
			}
		}
		// Risings and settings alternate, as do upper and lower transits.
		let crossings = events.filter { $0.kind == .rise || $0.kind == .set }.map(\.kind)
		#expect(zip(crossings, crossings.dropFirst()).allSatisfy { $0 != $1 })
		let transits = events.filter { $0.kind == .upperTransit || $0.kind == .lowerTransit }.map(\.kind)
		#expect(zip(transits, transits.dropFirst()).allSatisfy { $0 != $1 })
	}

	@Test func circumpolarTargets() throws {
		let tromso = try Self.site(2)
		let mcmurdo = try Self.site(3)
		// Capella never sets at Tromsø: transits only.
		let capella = try tromso.riseTransitSetEvents(of: Self.star(1), from: Self.instant(2_461_119.5), to: Self.instant(2_461_121.5), earthOrientation: Self.earthOrientation)
		#expect(!capella.isEmpty && capella.allSatisfy { $0.kind == .upperTransit || $0.kind == .lowerTransit })
		// The midnight Sun at Tromsø in June, and at McMurdo in December
		for (site, start) in [(tromso, 2_461_211.5), (mcmurdo, 2_461_395.5)] {
			let sun = try site.riseTransitSetEvents(of: .sun, from: Self.instant(start), to: Self.instant(start + 2), earthOrientation: Self.earthOrientation)
			#expect(sun.allSatisfy { $0.kind == .upperTransit || $0.kind == .lowerTransit })
			#expect(sun.filter { $0.kind == .lowerTransit }.allSatisfy { $0.place.altitude.radians > 0 })
		}
		// The polar night at McMurdo in June
		let night = try mcmurdo.riseTransitSetEvents(of: .sun, from: Self.instant(2_461_211.5), to: Self.instant(2_461_213.5), earthOrientation: Self.earthOrientation)
		#expect(night.allSatisfy { ($0.kind == .upperTransit || $0.kind == .lowerTransit) && $0.place.altitude.radians < 0 })
	}

	@Test func radii() throws {
		let site = try Self.site(0)
		let start = try Self.instant(2_461_119.5)
		let end = try Self.instant(2_461_120.5)
		// The standard altitude takes the Sun's upper limb from its radius, about 16', so it
		// rises about a minute and a half earlier than its center at -34'.
		let standard = try site.riseTransitSetEvents(of: .sun, from: start, to: end, earthOrientation: Self.earthOrientation).filter { $0.kind == .rise }
		let center = try site.riseTransitSetEvents(of: .sun, from: start, to: end, altitude: .center(altitude: .arcminutes(-34)), earthOrientation: Self.earthOrientation).filter { $0.kind == .rise }
		let difference = (Self.julianDate(center[0].instant) - Self.julianDate(standard[0].instant)) * secondsPerDay
		#expect(difference > 80 && difference < 120)
		// A radius of zero is the center at -34'.
		let point = try site.riseTransitSetEvents(of: .sun, from: start, to: end, altitude: .standard(radius: .zero), earthOrientation: Self.earthOrientation).filter { $0.kind == .rise }
		#expect(abs(Self.julianDate(point[0].instant) - Self.julianDate(center[0].instant)) * secondsPerDay < 0.2)
		// The built-in radii, and none by default for another ephemeris
		#expect(BuiltInEphemeris.radius(of: .sun) == .kilometers(695_700))
		#expect(BuiltInEphemeris.radius(of: .moon) == .kilometers(1_737.4))
		#expect(BuiltInEphemeris.radius(of: .earth) == .meters(6_378_137))
		#expect(BuiltInEphemeris.radius(of: .solarSystemBarycenter) == nil && BuiltInEphemeris.radius(of: .earthMoonBarycenter) == nil)
		#expect(BuiltInEphemeris.Body.allCases.filter { BuiltInEphemeris.radius(of: $0) != nil }.count == 11)
		#expect(AlteredEphemeris.radius(of: .sun) == nil)
		// With no radius, the Sun is a point.
		let altered = try site.riseTransitSetEvents(of: .sun, from: start, to: end, earthOrientation: Self.earthOrientation, ephemeris: AlteredEphemeris()).filter { $0.kind == .rise }
		#expect(abs(Self.julianDate(altered[0].instant) - Self.julianDate(center[0].instant)) * secondsPerDay < 0.2)
	}

	@Test func eventAltitudes() throws {
		#expect(EventAltitude.standard != (try EventAltitude.standard(radius: .zero)))
		#expect(EventAltitude.civilTwilight == (try EventAltitude.center(altitude: .degrees(-6))))
		#expect(EventAltitude.nauticalTwilight == (try EventAltitude.center(altitude: .degrees(-12))))
		#expect(EventAltitude.astronomicalTwilight == (try EventAltitude.center(altitude: .degrees(-18))))
		_ = try EventAltitude.center(altitude: .degrees(90))
		_ = try EventAltitude.center(altitude: .degrees(-90))
		#expect(throws: EventAltitudeError.nonFiniteValue) { try EventAltitude.center(altitude: .degrees(.nan)) }
		#expect(throws: EventAltitudeError.invalidAltitude) { try EventAltitude.center(altitude: .degrees(90.001)) }
		#expect(throws: EventAltitudeError.nonFiniteValue) { try EventAltitude.standard(radius: .kilometers(.infinity)) }
		#expect(throws: EventAltitudeError.invalidRadius) { try EventAltitude.standard(radius: .kilometers(-1)) }
	}

	@Test func intervals() throws {
		let site = try Self.site(0)
		let start = try Self.instant(2_461_119.5)
		// The geocenter has no horizon.
		#expect(throws: RiseTransitSetError.noHorizon) { try Observer.geocenter.riseTransitSetEvents(of: .sun, from: start, to: start) }
		#expect(throws: RiseTransitSetError.noHorizon) { try Observer.geocenter.riseTransitSetEvents(of: Self.star(0), from: start, to: start) }
		// The interval must not end before it starts.
		#expect(throws: RiseTransitSetError.invalidInterval) { try site.riseTransitSetEvents(of: .sun, from: start, to: Self.instant(2_461_119.4)) }
		// An empty interval has no events.
		#expect(try site.riseTransitSetEvents(of: .sun, from: start, to: start).isEmpty)
		// The ephemeris's errors pass through.
		let late = try Self.instant(2_816_795.4)
		#expect(throws: RiseTransitSetError.ephemeris(.outsideCoverage)) { try site.riseTransitSetEvents(of: .sun, from: late, to: Self.instant(2_816_795.6)) }
		// An interval in UTC gives the same events.
		let utcStart = try start.converted(to: UTC.self)
		let utcEnd = try Self.instant(2_461_120.5).converted(to: UTC.self)
		let inUTC = try site.riseTransitSetEvents(of: .moon, from: utcStart, to: utcEnd, earthOrientation: Self.earthOrientation)
		let inTT = try site.riseTransitSetEvents(of: .moon, from: start, to: Self.instant(2_461_120.5), earthOrientation: Self.earthOrientation)
		#expect(inUTC.map(\.kind) == inTT.map(\.kind))
		#expect(zip(inUTC, inTT).allSatisfy { abs(Self.julianDate($0.instant) - Self.julianDate($1.instant)) * secondsPerDay < 0.01 })
	}
}
