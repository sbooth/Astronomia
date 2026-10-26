//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// The searches that step toward a time the quantity can't be evaluated at, as past the end of
/// an ephemeris's coverage, stop and rethrow its error when no time between them is left to
/// tell, rather than stepping forever. A regression hangs these tests: a time limit can't stop
/// them, as a synchronous loop never checks for cancellation.
@Suite struct SearchCoverageTests {
	struct Unavailable: Error, Equatable {}

	/// The length of an interval whose end, just below a day, rounds a halving step back to the
	/// last sample once the samples come within an ulp of it.
	static let length = 1.0.nextDown

	@Test func crossingSearch() {
		let search = CrossingSearch<Unavailable>(length: Self.length, step: 1, skip: 10) { (days: Double) throws(Unavailable) -> Double in
			guard days < Self.length else { throw Unavailable() }
			return 1
		}
		#expect(throws: Unavailable()) { try search.crossings() }
	}

	@Test func extremumSearch() {
		let search = ExtremumSearch<Unavailable>(length: Self.length, step: 1, skip: 10) { (days: Double) throws(Unavailable) -> Double in
			guard days < Self.length else { throw Unavailable() }
			return 1
		}
		#expect(throws: Unavailable()) { try search.extremes() }
	}

	@Test func riseTransitSetSearch() {
		let instant = Instant<TT>(JulianDate.j2000)
		let search = RiseTransitSetSearch(length: Self.length) { (days: Double) throws(RiseTransitSetError) -> RiseTransitSetSearch.Sample in
			guard days < Self.length else { throw .ephemeris(.outsideCoverage) }
			// Always up, at an hour angle that doesn't reach a transit
			let place = ObservedPlace(azimuth: .zero, altitude: .degrees(45), hourAngle: .degrees(90), declination: .zero, parallacticAngle: .zero, distance: .astronomicalUnits(1), instant: instant)
			return RiseTransitSetSearch.Sample(time: days, instant: instant, hourAngle: place.hourAngle.radians, height: 1, place: place)
		}
		#expect(throws: RiseTransitSetError.ephemeris(.outsideCoverage)) { try search.events() }
	}

	@Test func quarterSearch() {
		// An angle that never reaches the next quarter before the end
		let search = QuarterSearch<Unavailable>(length: Self.length, meanMotion: 0.01, margin: 0.5) { (days: Double) throws(Unavailable) -> QuarterSearch<Unavailable>.Sample in
			guard days < Self.length else { throw Unavailable() }
			return .init(time: days, instant: Instant<TT>(JulianDate.j2000), angle: 0.1 + 0.01 * days)
		}
		let lower = QuarterSearch<Unavailable>.Sample(time: 0, instant: Instant<TT>(JulianDate.j2000), angle: 0.1)
		#expect(throws: Unavailable()) { try search.sampleAfter(lower, past: { $0.angle - halfPi }, at: Self.length) }
	}
}
