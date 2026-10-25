//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct NextRiseTransitSetEventTests {
	typealias Fixtures = RiseTransitSetTests

	static func seconds(from a: Instant<TT>, to b: Instant<TT>) -> Double {
		(b.julianDate.daysSinceJ2000 - a.julianDate.daysSinceJ2000) * secondsPerDay
	}

	static func adding(seconds: Double, to instant: Instant<TT>) throws -> Instant<TT> {
		Instant(try instant.julianDate.adding(seconds: seconds))
	}

	@Test func findsEachEvent() throws {
		// Each event of the Sun and the Moon over two days at Greenwich is the next of its kind
		// from an hour or two seconds before it, and from it, the next of its kind is about a
		// day later.
		let greenwich = try Fixtures.site(0)
		let start = try Fixtures.instant(2_461_041.5)
		for body in [BuiltInEphemeris.Body.sun, .moon] {
			let events = try greenwich.riseTransitSetEvents(of: body, from: start, to: Fixtures.instant(2_461_043.5), earthOrientation: Fixtures.earthOrientation)
			#expect(Set(events.map(\.kind)) == Set(RiseTransitSetEvent.Kind.allCases))
			for event in events {
				for before in [3_600.0, 2] {
					let found = try greenwich.nextRiseTransitSetEvent(event.kind, of: body, after: Self.adding(seconds: -before, to: event.instant), earthOrientation: Fixtures.earthOrientation)
					#expect(found.kind == event.kind)
					#expect(abs(Self.seconds(from: event.instant, to: found.instant)) < 0.1, "\(body) \(event.kind) \(before)")
				}
				let later = try greenwich.nextRiseTransitSetEvent(event.kind, of: body, after: event.instant, earthOrientation: Fixtures.earthOrientation)
				let days = Self.seconds(from: event.instant, to: later.instant) / secondsPerDay
				#expect(days > 0.95 && days < 1.1, "\(body) \(event.kind): \(days)")
			}
		}
	}

	@Test func stars() throws {
		// A star's next rise is a sidereal day after the last, and one that never sets still
		// transits.
		let greenwich = try Fixtures.site(0)
		let tromso = try Fixtures.site(2)
		let start = try Fixtures.instant(2_461_119.5)
		let rise = try greenwich.nextRiseTransitSetEvent(.rise, of: Fixtures.star(0), after: start, earthOrientation: Fixtures.earthOrientation)
		let next = try greenwich.nextRiseTransitSetEvent(.rise, of: Fixtures.star(0), after: rise.instant, earthOrientation: Fixtures.earthOrientation)
		#expect(abs(Self.seconds(from: rise.instant, to: next.instant) - 86_164.1) < 5)
		let capella = try Fixtures.star(1)
		#expect(try tromso.nextRiseTransitSetEvent(.upperTransit, of: capella, after: start, earthOrientation: Fixtures.earthOrientation).place.altitude.radians > 0)
		#expect(throws: RiseTransitSetError.eventNotFound) {
			try tromso.nextRiseTransitSetEvent(.set, of: capella, after: start, earthOrientation: Fixtures.earthOrientation)
		}
	}

	@Test func limits() throws {
		let greenwich = try Fixtures.site(0)
		let mcmurdo = try Fixtures.site(3)
		let start = try Fixtures.instant(2_461_041.5)
		// From just after a sunrise, the next is about a day later, past a limit of half a day.
		let sunrise = try greenwich.nextRiseTransitSetEvent(.rise, of: .sun, after: start, earthOrientation: Fixtures.earthOrientation)
		let after = try Self.adding(seconds: 60, to: sunrise.instant)
		#expect(throws: RiseTransitSetError.eventNotFound) {
			try greenwich.nextRiseTransitSetEvent(.rise, of: .sun, after: after, within: .seconds(43_200), earthOrientation: Fixtures.earthOrientation)
		}
		#expect(try greenwich.nextRiseTransitSetEvent(.rise, of: .sun, after: after, within: .days(1), earthOrientation: Fixtures.earthOrientation).kind == .rise)
		// In the polar night at McMurdo in June the Sun doesn't rise within the default limit,
		// but it transits, and it rises within three months.
		let june = try Fixtures.instant(2_461_211.5)
		#expect(throws: RiseTransitSetError.eventNotFound) {
			try mcmurdo.nextRiseTransitSetEvent(.rise, of: .sun, after: june, earthOrientation: Fixtures.earthOrientation)
		}
		#expect(try mcmurdo.nextRiseTransitSetEvent(.upperTransit, of: .sun, after: june, earthOrientation: Fixtures.earthOrientation).place.altitude.radians < 0)
		let return_ = try mcmurdo.nextRiseTransitSetEvent(.rise, of: .sun, after: june, within: .days(90), earthOrientation: Fixtures.earthOrientation)
		let days = Self.seconds(from: june, to: return_.instant) / secondsPerDay
		#expect(days > 50 && days < 75, "\(days)")
	}

	@Test func errors() throws {
		let start = try Fixtures.instant(2_461_041.5)
		#expect(throws: RiseTransitSetError.noHorizon) {
			try Observer.geocenter.nextRiseTransitSetEvent(.rise, of: .sun, after: start)
		}
		#expect(throws: RiseTransitSetError.invalidInterval) {
			try Fixtures.site(0).nextRiseTransitSetEvent(.rise, of: .sun, after: start, within: .days(-1))
		}
		#expect(throws: RiseTransitSetError.ephemeris(.outsideCoverage)) {
			try Fixtures.site(0).nextRiseTransitSetEvent(.rise, of: .sun, after: Instant<TT>(JulianDate(year: 900, month: 1, day: 1)))
		}
	}

	@Test func fromUTC() throws {
		// From an instant in UTC, the same event
		let greenwich = try Fixtures.site(0)
		let start = try Fixtures.instant(2_461_041.5)
		let sunset = try greenwich.nextRiseTransitSetEvent(.set, of: .sun, after: start)
		let found = try greenwich.nextRiseTransitSetEvent(.set, of: .sun, after: start.converted(to: UTC.self))
		#expect(abs(Self.seconds(from: sunset.instant, to: found.instant)) < 0.1)
	}
}
