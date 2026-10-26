//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LocalLunarEclipseTests {
	/// The total eclipse of 2025 March 14, greatest at 06:59 TT
	static let march2025 = Result { try Moon.nextEclipse(after: Instant<TT>(try JulianDate(year: 2025, month: 3, day: 1)), precision: .arcsecond) }

	static let maunaKea = try! Observer.site(latitude: .degrees(19.8207), longitude: .degrees(-155.4681), height: .meters(4205))
	static let greenwich = try! Observer.site(latitude: .degrees(51.4769), longitude: .degrees(-0.0005), height: .meters(46))
	static let chicago = try! Observer.site(latitude: .degrees(41.8781), longitude: .degrees(-87.6298), height: .meters(180))
	static let delhi = try! Observer.site(latitude: .degrees(28.6139), longitude: .degrees(77.2090), height: .meters(216))

	/// Returns whether two instants are within a second, as for eclipses found by searches
	/// with different origins.
	static func near(_ a: Instant<TT>, _ b: Instant<TT>) -> Bool {
		abs(a.julianDate.daysSinceJ2000 - b.julianDate.daysSinceJ2000) * 86400 < 1
	}

	@Test func wholeEclipseVisible() throws {
		// From Chicago the Moon is up through the eclipse, from 23:00 on March 13, local time, to
		// 05:00 on March 14.
		let eclipse = try Self.march2025.get()
		let local = try Self.chicago.localCircumstances(of: eclipse)
		#expect(local.eclipse == eclipse && local.observer == Self.chicago)
		#expect(local.contacts.map(\.contact) == Moon.LocalEclipse.Contact.allCases)
		#expect(local.contacts.allSatisfy { $0.isMoonUp && $0.place.altitude.degrees > 10 })
		#expect(local.moonrisesAndMoonsets.isEmpty)
		#expect(local.visibleIntervals == [eclipse.penumbralPhase])
		#expect(local.visibleIntervals(of: eclipse.totalPhase!) == [eclipse.totalPhase!])
		// The places are those of an observation at each contact.
		for circumstance in local.contacts {
			let sky = try Self.chicago.observation(at: circumstance.instant, ephemeris: BuiltInEphemeris(precision: .arcsecond))
			let place = try sky.observedPlace(of: sky.apparentPlace(of: .moon))
			#expect(circumstance.place == place)
		}
		#expect(local.circumstance(at: .greatestEclipse)?.instant == eclipse.greatestEclipse)
		#expect(local.circumstance(at: .totalBegins)?.instant == eclipse.totalPhase?.lowerBound)
	}

	@Test func moonSetsDuringTheEclipse() throws {
		// From Greenwich the Moon sets in the morning twilight, after the total phase begins.
		let eclipse = try Self.march2025.get()
		let local = try Self.greenwich.localCircumstances(of: eclipse)
		#expect(local.moonrisesAndMoonsets.map(\.kind) == [.set])
		let moonset = try #require(local.moonrisesAndMoonsets.first).instant
		#expect(local.visibleIntervals == [eclipse.penumbralPhase.lowerBound ... moonset])
		#expect(eclipse.penumbralPhase.contains(moonset))
		// The contacts before the moonset are seen, and those after aren't.
		for circumstance in local.contacts {
			#expect(circumstance.isMoonUp == (circumstance.instant < moonset), "\(circumstance.contact)")
			#expect(circumstance.isMoonUp == (circumstance.place.altitude.degrees > -1), "\(circumstance.contact)")
		}
		// The set matches the rise and set search over the eclipse.
		let events = try Self.greenwich.riseTransitSetEvents(of: .moon, from: eclipse.penumbralPhase.lowerBound, to: eclipse.penumbralPhase.upperBound)
		#expect(events.filter { $0.kind == .set }.map(\.instant) == [moonset])
		#expect(local.isVisible)
	}

	@Test func moonRisesDuringTheEclipse() throws {
		// From Mauna Kea the Moon rises at dusk on March 13 after the first contact with the
		// penumbra, and is up for the rest of the eclipse.
		let eclipse = try Self.march2025.get()
		let local = try Self.maunaKea.localCircumstances(of: eclipse)
		#expect(local.moonrisesAndMoonsets.map(\.kind) == [.rise])
		let moonrise = try #require(local.moonrisesAndMoonsets.first).instant
		#expect(moonrise > eclipse.penumbralPhase.lowerBound && moonrise < eclipse.partialPhase!.lowerBound)
		#expect(local.visibleIntervals == [moonrise ... eclipse.penumbralPhase.upperBound])
		#expect(local.contacts.map(\.isMoonUp) == [false, true, true, true, true, true, true])
		#expect(local.visibleIntervals(of: eclipse.penumbralPhase) == [moonrise ... eclipse.penumbralPhase.upperBound])
		#expect(local.visibleIntervals(of: eclipse.totalPhase!) == [eclipse.totalPhase!])
	}

	@Test func notVisible() throws {
		// From Delhi the eclipse ends at 15:30 local time, before the Moon rises.
		let eclipse = try Self.march2025.get()
		let local = try Self.delhi.localCircumstances(of: eclipse)
		#expect(!local.isVisible)
		#expect(local.visibleIntervals.isEmpty && local.moonrisesAndMoonsets.isEmpty)
		#expect(local.contacts.allSatisfy { !$0.isMoonUp && $0.place.altitude.degrees < 0 })
		#expect(local.visibleIntervals(of: eclipse.penumbralPhase).isEmpty)
	}

	@Test func refractionAndAltitude() throws {
		let eclipse = try Self.march2025.get()
		// Refraction raises the places but doesn't decide whether the Moon is up.
		let refracted = try Self.greenwich.localCircumstances(of: eclipse, conditions: .standard)
		let plain = try Self.greenwich.localCircumstances(of: eclipse)
		for (a, b) in zip(refracted.contacts, plain.contacts) {
			#expect(a.place.altitude > b.place.altitude && a.isMoonUp == b.isMoonUp)
		}
		#expect(refracted.visibleIntervals == plain.visibleIntervals)
		// A higher horizon sets the Moon earlier.
		let trees = try EventAltitude.center(altitude: .degrees(5))
		let high = try Self.greenwich.localCircumstances(of: eclipse, altitude: trees)
		let moonset = try #require(high.moonrisesAndMoonsets.first).instant
		#expect(moonset < plain.moonrisesAndMoonsets[0].instant)
		#expect(high.visibleIntervals == [eclipse.penumbralPhase.lowerBound ... moonset])
	}

	@Test func visibleEclipses() throws {
		// Of the eclipses of 2025 and 2026, those seen from Mauna Kea, each with the Moon up for
		// part of it
		let start = Instant<TT>(try JulianDate(year: 2025, month: 1, day: 1))
		let end = Instant<TT>(try JulianDate(year: 2027, month: 1, day: 1))
		let all = try Moon.eclipses(from: start, to: end, precision: .arcsecond)
		let visible = try Self.maunaKea.visibleLunarEclipses(from: start, to: end, precision: .arcsecond)
		#expect(all.count == 4 && !visible.isEmpty && visible.count <= all.count)
		#expect(visible.allSatisfy { $0.isVisible })
		for eclipse in all {
			let local = try Self.maunaKea.localCircumstances(of: eclipse)
			#expect(local.isVisible == visible.contains { Self.near($0.eclipse.greatestEclipse, eclipse.greatestEclipse) })
		}
		let march = try Self.march2025.get().greatestEclipse
		#expect(visible.contains { Self.near($0.eclipse.greatestEclipse, march) })
		// From Delhi, the eclipse of March 2025 isn't seen.
		#expect(try Self.delhi.visibleLunarEclipses(from: Instant<TT>(try JulianDate(year: 2025, month: 3, day: 1)), to: Instant<TT>(try JulianDate(year: 2025, month: 4, day: 1)), precision: .arcsecond).isEmpty)
	}

	@Test func errors() throws {
		let eclipse = try Self.march2025.get()
		#expect(throws: Moon.EclipseError.noHorizon) { try Observer.geocenter.localCircumstances(of: eclipse) }
		let start = Instant<TT>(try JulianDate(year: 2025, month: 1, day: 1))
		#expect(throws: Moon.EclipseError.noHorizon) { try Observer.geocenter.visibleLunarEclipses(from: start, to: start, precision: .arcsecond) }
		#expect(throws: Moon.EclipseError.invalidInterval) {
			try Self.maunaKea.visibleLunarEclipses(from: start, to: Instant<TT>(try JulianDate(year: 2024, month: 1, day: 1)), precision: .arcsecond)
		}
	}
}
