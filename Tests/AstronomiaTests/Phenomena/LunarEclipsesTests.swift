//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LunarEclipsesTests {
	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the length of a phase, in minutes.
	static func minutes(_ phase: ClosedRange<Instant<TT>>?) -> Double? {
		phase.map { (julianDate($0.upperBound) - julianDate($0.lowerBound)) * 1440 }
	}

	/// Returns the instant of greatest eclipse of a NASA eclipse.
	static func greatest(_ eclipse: (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, kind: LunarEclipse.Kind, gamma: Double, penumbralMagnitude: Double, umbralMagnitude: Double, penumbral: Double, partial: Double?, total: Double?)) throws -> Instant<TT> {
		let day = try JulianDate(year: eclipse.year, month: eclipse.month, day: eclipse.day)
		return Instant(try day.adding(seconds: Double(eclipse.hour * 3600 + eclipse.minute * 60 + eclipse.second)))
	}

	/// Returns whether two eclipses are the same, found from searches with other origins, so
	/// to within the precision of the search.
	static func same(_ a: LunarEclipse, _ b: LunarEclipse) -> Bool {
		a.kind == b.kind && abs(julianDate(a.greatestEclipse) - julianDate(b.greatestEclipse)) * 86400 < 0.05 && abs(a.umbralMagnitude - b.umbralMagnitude) < 1e-9
	}

	@Test func matchesNASA() throws {
		// A third of the eclipses of 2001 to 2049 at 1": greatest eclipse within 2 s of NASA's
		// Five Millennium Catalog, with DE406, gamma within 0.0002, the magnitudes within 0.001,
		// and the phases within 0.4 minutes, but those of a Moon that grazes the edge of the
		// penumbra or the umbra, whose lengths change quickly with its path
		for (index, expected) in nasaLunarEclipses.enumerated() where index % 3 == 0 {
			let greatest = try Self.greatest(expected)
			let eclipse = try LunarEclipses.next(after: Instant<TT>(try greatest.julianDate.adding(days: -2)), precision: .arcsecond)
			let comment = Comment(rawValue: "\(expected)")
			#expect(eclipse.kind == expected.kind, comment)
			#expect(abs(Self.julianDate(eclipse.greatestEclipse) - Self.julianDate(greatest)) * 86400 <= 2, comment)
			#expect(abs(eclipse.gamma - expected.gamma) <= 2e-4, comment)
			#expect(abs(eclipse.penumbralMagnitude - expected.penumbralMagnitude) <= 1e-3, comment)
			#expect(abs(eclipse.umbralMagnitude - expected.umbralMagnitude) <= 1e-3, comment)
			let penumbral = try #require(Self.minutes(eclipse.penumbralPhase))
			#expect(abs(penumbral - expected.penumbral) <= (expected.penumbral < 60 ? 3 : 0.4), comment)
			#expect((Self.minutes(eclipse.partialPhase) == nil) == (expected.partial == nil), comment)
			if let partial = Self.minutes(eclipse.partialPhase), let expectedPartial = expected.partial {
				#expect(abs(partial - expectedPartial) <= (expectedPartial < 60 ? 1.5 : 0.4), comment)
			}
			#expect((Self.minutes(eclipse.totalPhase) == nil) == (expected.total == nil), comment)
			if let total = Self.minutes(eclipse.totalPhase), let expectedTotal = expected.total {
				#expect(abs(total - expectedTotal) <= (expectedTotal < 10 ? 1.5 : 0.4), comment)
			}
		}
	}

	@Test func matchesSkyfield() throws {
		// Eclipses of 1900 to 2049 at 1": greatest eclipse within 2.5 s of Skyfield's, with
		// DE421, and the radii of the shadow within 1.5" and of the Moon within 0.3". Skyfield
		// takes the Moon's place without aberration, but the Sun's with it, which moves the
		// Moon's distance from the axis by up to about 6", and the magnitudes with it, by up to
		// 0.004.
		for (index, expected) in skyfieldLunarEclipses.enumerated() where index % 15 == 7 {
			let greatest = Instant<TT>(try JulianDate(julianDate: expected.whole + expected.fraction))
			let eclipse = try LunarEclipses.next(after: Instant<TT>(try greatest.julianDate.adding(days: -2)), precision: .arcsecond)
			let comment = Comment(rawValue: "\(expected)")
			#expect(eclipse.kind == expected.kind, comment)
			#expect(abs(Self.julianDate(eclipse.greatestEclipse) - Self.julianDate(greatest)) * 86400 <= 2.5, comment)
			#expect(abs(eclipse.penumbraRadius.radians - expected.penumbra) * 206_265 <= 1.5, comment)
			#expect(abs(eclipse.umbraRadius.radians - expected.umbra) * 206_265 <= 1.5, comment)
			#expect(abs(eclipse.moonRadius.radians - expected.moon) * 206_265 <= 0.3, comment)
			#expect(abs(eclipse.separation.radians - expected.separation) * 206_265 <= 7, comment)
			#expect(abs(eclipse.umbralMagnitude - expected.umbralMagnitude) <= 0.004, comment)
			#expect(abs(eclipse.penumbralMagnitude - expected.penumbralMagnitude) <= 0.004, comment)
		}
	}

	@Test func events() throws {
		// The eclipses of 2025 to 2029 are NASA's, in order.
		let start = Instant<TT>(try JulianDate(year: 2025, month: 1, day: 1))
		let end = Instant<TT>(try JulianDate(year: 2030, month: 1, day: 1))
		let eclipses = try LunarEclipses.events(from: start, to: end, precision: .arcsecond)
		let expected = nasaLunarEclipses.filter { $0.year >= 2025 && $0.year < 2030 }
		#expect(eclipses.count == expected.count && expected.count == 12)
		for (eclipse, expected) in zip(eclipses, expected) {
			#expect(eclipse.kind == expected.kind)
			#expect(abs(Self.julianDate(eclipse.greatestEclipse) - Self.julianDate(try Self.greatest(expected))) * 86400 <= 2)
			#expect(eclipse.shadowModel == .danjon)
		}
		// The contacts are in order about greatest eclipse.
		for eclipse in eclipses {
			let greatest = eclipse.greatestEclipse
			#expect(eclipse.penumbralPhase.contains(greatest))
			if let partial = eclipse.partialPhase {
				#expect(eclipse.penumbralPhase.lowerBound < partial.lowerBound && partial.upperBound < eclipse.penumbralPhase.upperBound)
				#expect(partial.contains(greatest))
			}
			if let total = eclipse.totalPhase, let partial = eclipse.partialPhase {
				#expect(partial.lowerBound < total.lowerBound && total.upperBound < partial.upperBound)
				#expect(total.contains(greatest))
			}
			#expect((eclipse.partialPhase != nil) == (eclipse.kind != .penumbral))
			#expect((eclipse.totalPhase != nil) == (eclipse.kind == .total))
			#expect(eclipse.umbralMagnitude < eclipse.penumbralMagnitude)
		}
		// Two eclipses a fortnight apart, in 2027, the second barely penumbral
		let july = try LunarEclipses.events(from: Instant<TT>(try JulianDate(year: 2027, month: 7, day: 1)), to: Instant<TT>(try JulianDate(year: 2027, month: 9, day: 1)), precision: .arcsecond)
		#expect(july.map(\.kind) == [.penumbral, .penumbral])
		#expect(july.first.map { $0.penumbralMagnitude > 0 && $0.penumbralMagnitude < 0.01 } == true)
	}

	@Test func intervalEnds() throws {
		// An eclipse is in an interval when its greatest eclipse is, though its full Moon or its
		// contacts are outside.
		let eclipse = try LunarEclipses.next(after: Instant<TT>(try JulianDate(year: 2025, month: 3, day: 1)), precision: .arcsecond)
		let greatest = eclipse.greatestEclipse
		let full = try MoonPhases.next(.fullMoon, after: Instant<TT>(try greatest.julianDate.adding(days: -1)), precision: .arcsecond)
		#expect(abs(Self.julianDate(full) - Self.julianDate(greatest)) < 0.05)
		func around(_ before: Double, _ after: Double) throws -> [LunarEclipse] {
			try LunarEclipses.events(from: Instant<TT>(try greatest.julianDate.adding(seconds: before)), to: Instant<TT>(try greatest.julianDate.adding(seconds: after)), precision: .arcsecond)
		}
		let found = try around(-60, 60)
		#expect(found.count == 1 && Self.same(found[0], eclipse))
		#expect(try around(-3600, -1).isEmpty)
		#expect(try around(1, 3600).isEmpty)
		// Intervals with the full Moon outside them and greatest eclipse inside: the full Moon of
		// March 2025 is about 5 minutes before greatest eclipse.
		let gap = (Self.julianDate(greatest) - Self.julianDate(full)) * 86400
		#expect(gap > 60)
		let afterFull = try around(-gap / 2, 7200)
		#expect(afterFull.count == 1 && Self.same(afterFull[0], eclipse))
		// And an interval that ends between greatest eclipse and a later full Moon
		let (laterEclipse, lead) = try Self.eclipseBeforeFullMoon(after: Instant<TT>(try JulianDate(year: 2025, month: 4, day: 1)))
		let beforeFull = try LunarEclipses.events(from: Instant<TT>(try laterEclipse.greatestEclipse.julianDate.adding(seconds: -7200)), to: Instant<TT>(try laterEclipse.greatestEclipse.julianDate.adding(seconds: lead / 2)), precision: .arcsecond)
		#expect(beforeFull.count == 1 && Self.same(beforeFull[0], laterEclipse))
		// A greatest eclipse just after the start of `next`, whose full Moon is before it
		let next = try LunarEclipses.next(after: Instant<TT>(try greatest.julianDate.adding(seconds: -gap / 2)), precision: .arcsecond)
		#expect(Self.same(next, eclipse))
	}

	@Test func shadowModels() throws {
		// Chauvenet's shadow is larger: umbral magnitudes about 0.005 larger and penumbral about
		// 0.026.
		let start = Instant<TT>(try JulianDate(year: 2025, month: 1, day: 1))
		let danjon = try LunarEclipses.next(after: start, precision: .arcsecond)
		let chauvenet = try LunarEclipses.next(after: start, precision: .arcsecond, shadowModel: .chauvenet)
		#expect(chauvenet.shadowModel == .chauvenet)
		#expect(abs(Self.julianDate(chauvenet.greatestEclipse) - Self.julianDate(danjon.greatestEclipse)) * 86400 < 0.5)
		let umbral = chauvenet.umbralMagnitude - danjon.umbralMagnitude
		let penumbral = chauvenet.penumbralMagnitude - danjon.penumbralMagnitude
		#expect(umbral > 0.003 && umbral < 0.008)
		#expect(penumbral > 0.02 && penumbral < 0.03)
		#expect(chauvenet.umbraRadius > danjon.umbraRadius && chauvenet.penumbraRadius > danjon.penumbraRadius)
		#expect(chauvenet.moonRadius == danjon.moonRadius)
		#expect(Self.minutes(chauvenet.penumbralPhase)! > Self.minutes(danjon.penumbralPhase)!)
	}

	@Test func errors() throws {
		let start = Instant<TT>(try JulianDate(year: 2025, month: 1, day: 1))
		#expect(throws: LunarEclipseError.invalidInterval) {
			try LunarEclipses.events(from: start, to: Instant<TT>(try JulianDate(year: 2024, month: 1, day: 1)), precision: .arcsecond)
		}
		#expect(try LunarEclipses.events(from: start, to: start, precision: .arcsecond).isEmpty)
		// Outside the coverage
		#expect(throws: LunarEclipseError.ephemeris(.outsideCoverage)) {
			try LunarEclipses.next(after: Instant<TT>(try JulianDate(year: 3000, month: 6, day: 1)), precision: .tenArcseconds)
		}
		// A Moon that keeps 45° from the Sun is never eclipsed.
		#expect(throws: LunarEclipseError.eclipseNotFound) {
			try LunarEclipses.next(of: .moon, after: start, ephemeris: CircularEphemeris())
		}
		#expect(try LunarEclipses.events(of: .moon, from: start, to: Instant<TT>(try JulianDate(year: 2026, month: 1, day: 1)), ephemeris: CircularEphemeris()).isEmpty)
		// From UTC
		let utc = try start.converted(to: UTC.self)
		#expect(Self.same(try LunarEclipses.next(after: utc, precision: .arcsecond), try LunarEclipses.next(after: start, precision: .arcsecond)))
	}

	/// Returns the first eclipse greatest after an instant whose full Moon is after its greatest
	/// eclipse by more than a minute, and the interval between them, in seconds.
	static func eclipseBeforeFullMoon(after instant: Instant<TT>) throws -> (eclipse: LunarEclipse, lead: Double) {
		var from = instant
		for _ in 0 ..< 10 {
			let eclipse = try LunarEclipses.next(after: from, precision: .arcsecond)
			let full = try MoonPhases.next(.fullMoon, after: Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(days: -1)), precision: .arcsecond)
			let lead = (julianDate(full) - julianDate(eclipse.greatestEclipse)) * 86400
			if lead > 60 {
				return (eclipse, lead)
			}
			from = eclipse.greatestEclipse
		}
		throw LunarEclipseError.eclipseNotFound
	}

	@Test func repeatedNext() throws {
		// From the greatest eclipse of one eclipse, the next is the next, not the same one found
		// a little later, whether its full Moon is before greatest eclipse, as in March 2025, or
		// after it.
		let march = try LunarEclipses.next(after: Instant<TT>(try JulianDate(year: 2025, month: 3, day: 1)), precision: .arcsecond)
		let (later, _) = try Self.eclipseBeforeFullMoon(after: Instant<TT>(try JulianDate(year: 2025, month: 4, day: 1)))
		for eclipse in [march, later] {
			for offset in [-0.3, 0, 0.3] {
				let from = Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(seconds: offset))
				let next = try LunarEclipses.next(after: from, precision: .arcsecond)
				#expect(Self.julianDate(next.greatestEclipse) - Self.julianDate(eclipse.greatestEclipse) > 100, "\(offset)")
			}
			// From a second before, the same one
			let before = try LunarEclipses.next(after: Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(seconds: -1)), precision: .arcsecond)
			#expect(Self.same(before, eclipse))
		}
	}

	@Test func endOfTheCoverage() throws {
		// An eclipse whose last contact is 5 minutes before the end of the coverage is found,
		// though the samples that bracket its contacts and its greatest eclipse run past it: a
		// total eclipse, and a penumbral eclipse of 12 minutes.
		let start = Instant<TT>(try JulianDate(year: 2025, month: 3, day: 1))
		let total = try LunarEclipses.next(after: start, precision: .arcsecond)
		let penumbral = try LunarEclipses.next(after: Instant<TT>(try JulianDate(year: 2027, month: 7, day: 10)), precision: .arcsecond)
		#expect(total.kind == .total && Self.minutes(penumbral.penumbralPhase)! < 15)
		for eclipse in [total, penumbral] {
			let from = Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(days: -10))
			let end = eclipse.penumbralPhase.upperBound
			let covered = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try end.julianDate.adding(seconds: 300)))
			let found = try LunarEclipses.next(of: .moon, after: from, ephemeris: covered)
			#expect(Self.same(found, eclipse))
			#expect(abs(Self.julianDate(found.penumbralPhase.upperBound) - Self.julianDate(end)) * 86400 < 0.2)
			let inInterval = try LunarEclipses.events(of: .moon, from: from, to: Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(seconds: 60)), ephemeris: covered)
			#expect(inInterval.count == 1 && Self.same(inInterval[0], eclipse))
			// The last contact past the end of the coverage
			let short = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try end.julianDate.adding(seconds: -60)))
			#expect(throws: LunarEclipseError.ephemeris(.outsideCoverage)) { try LunarEclipses.next(of: .moon, after: from, ephemeris: short) }
		}
	}
}
