//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct JPLEphemerisTests {
	/// The DE421 excerpt, October 15 to November 15, 2025.
	static let excerpt = try! SPKFile(contentsOf: SPKKernelTests.excerptPath)

	/// Returns the instant of TDB seconds from J2000.0.
	static func instant(_ seconds: Double) throws -> Instant<TDB> {
		Instant(try JulianDate(daysSinceJ2000: seconds / secondsPerDay))
	}

	/// The jplephem state of a segment at an instant, in km and km/s.
	static func reference(_ target: Int, _ center: Int, _ seconds: Double) throws -> (position: Vector3, velocity: Vector3) {
		let row = try #require(jplephemSPKStates.first { $0.target == target && $0.center == center && $0.seconds == seconds })
		return (Vector3(row.position[0], row.position[1], row.position[2]), Vector3(row.velocity[0], row.velocity[1], row.velocity[2]))
	}

	/// Expects a state in au and au/day to match one in km and km/s.
	static func expect(_ state: StateVector<ICRS>, matches reference: (position: Vector3, velocity: Vector3), _ comment: Comment) {
		let position = state.position.vector * kilometersPerAstronomicalUnit
		let velocity = state.velocity.vector * (kilometersPerAstronomicalUnit / secondsPerDay)
		// The instant's rounding through days moves a body by micrometers.
		#expect((position - reference.position).length <= 1e-5 + 1e-14 * reference.position.length, comment)
		#expect((velocity - reference.velocity).length <= 1e-12 * reference.velocity.length, comment)
	}

	@Test func bodiesHaveTheirNAIFIDsAndRadii() throws {
		#expect(JPLEphemeris.Body.allCases.map { $0.naifID } == [0, 10, 199, 299, 3, 399, 301, 4, 5, 6, 7, 8, 9])
		#expect(BuiltInEphemeris.Body.allCases.map { $0.naifID } == [0, 10, 199, 299, 3, 399, 301, 499, 5, 6, 7, 8, 9])
		// The same bodies have the same radii in each ephemeris.
		for body in BuiltInEphemeris.Body.allCases {
			let id = try #require(body.naifID)
			#expect(SPKEphemeris.Body(naifID: id).radius == body.radius)
			if let jpl = JPLEphemeris.Body.allCases.first(where: { $0.naifID == id }) {
				#expect(jpl.radius == body.radius)
			}
		}
		#expect(JPLEphemeris.Body.marsBarycenter.radius == BuiltInEphemeris.Body.mars.radius)
		#expect(SPKEphemeris.Body.earthMoonBarycenter.radius == nil && SPKEphemeris.Body(naifID: 2_000_001).radius == nil)
		#expect(SPKEphemeris.Body.moon == SPKEphemeris.Body(naifID: 301))
	}

	@Test func theFileListsItsSegments() throws {
		#expect(Self.excerpt.segments.count == 15)
		#expect(Self.excerpt.segments.allSatisfy { $0.isSupported })
		let earth = try #require(Self.excerpt.segments.first { $0.target == 399 })
		#expect(earth.center == 3 && earth.frame == 1 && earth.type == 2)
		#expect(earth.coverage.lowerBound == (try Self.instant(813_758_400)))
		#expect(earth.coverage.upperBound == (try Self.instant(816_436_800)))
	}

	@Test func statesAreTheSumsOfTheSegments() throws {
		let ephemeris = try JPLEphemeris(file: Self.excerpt)
		#expect(ephemeris.coverage == Self.excerpt.segments[0].coverage)
		// The instants of every segment: its ends and the instants between
		let instants = [1, 3, 10, 199, 301, 399].map { target in Set(jplephemSPKStates.filter { $0.target == target }.map(\.seconds)) }
		let common = instants.dropFirst().reduce(instants[0]) { $0.intersection($1) }
		#expect(common.count == 5)
		for seconds in common {
			let tdb = try Self.instant(seconds)
			let emb = try Self.reference(3, 0, seconds)
			let earth = try Self.reference(399, 3, seconds)
			let moon = try Self.reference(301, 3, seconds)
			Self.expect(try ephemeris.state(of: .earth, relativeTo: .solarSystemBarycenter, at: tdb), matches: (emb.position + earth.position, emb.velocity + earth.velocity), "Earth at \(seconds)")
			// The Moon relative to the Earth joins at the Earth-Moon barycenter.
			Self.expect(try ephemeris.state(of: .moon, relativeTo: .earth, at: tdb), matches: (moon.position - earth.position, moon.velocity - earth.velocity), "Moon at \(seconds)")
			Self.expect(try ephemeris.state(of: .solarSystemBarycenter, relativeTo: .earthMoonBarycenter, at: tdb), matches: (-emb.position, -emb.velocity), "SSB at \(seconds)")
			let mercury = try Self.reference(1, 0, seconds)
			let sun = try Self.reference(10, 0, seconds)
			Self.expect(try ephemeris.state(of: .mercury, relativeTo: .sun, at: tdb), matches: (mercury.position - sun.position + (try Self.reference(199, 1, seconds)).position, mercury.velocity - sun.velocity + (try Self.reference(199, 1, seconds)).velocity), "Mercury at \(seconds)")
		}
	}

	@Test func otherSegmentsAreGivenByAnSPKEphemeris() throws {
		let ephemeris = try SPKEphemeris(files: [Self.excerpt])
		#expect(ephemeris.coverage == Self.excerpt.segments[0].coverage)
		let seconds = 815_000_000.0
		let mars = ephemeris.index.state(of: 499, relativeTo: 0, at: seconds)
		let system = ephemeris.index.state(of: 4, relativeTo: 0, at: seconds)
		let center = ephemeris.index.state(of: 499, relativeTo: 4, at: seconds)
		#expect(mars?.position == (system?.position).map { $0 + (center?.position ?? .zero) })
		_ = try ephemeris.state(of: .mars, relativeTo: .earth, at: Self.instant(seconds))
		// A body the file doesn't give
		#expect(throws: EphemerisError.outsideCoverage) {
			try ephemeris.state(of: SPKEphemeris.Body(naifID: 2_000_001), relativeTo: .sun, at: Self.instant(seconds))
		}
	}

	@Test func placesMatchSkyfieldWithDE421() throws {
		// The places of Skyfield 1.55 with DE421 at 2460967.25, with the bodies of the built-in
		// ephemeris by their NAIF IDs, Mars's center among them
		let ephemeris = try SPKEphemeris(files: [Self.excerpt])
		let values = skyfieldPlaces.filter { $0.julianDate == 2_460_967.25 }
		#expect(values.count == 10)
		for value in values {
			let body = SPKEphemeris.Body(naifID: try #require(value.body.naifID))
			let tdb = try Instant<TDB>(JulianDate(julianDate: value.julianDate))
			let astrometric = try Observer.geocenter.astrometricPlace(of: body, at: tdb, ephemeris: ephemeris)
			let apparent = try Observer.geocenter.apparentPlace(of: body, at: tdb, ephemeris: ephemeris)
			let reference = PlaceTests.vector(value.astrometric)
			let direction = (PlaceTests.unit(astrometric.position.vector) - PlaceTests.unit(reference)).length * PlaceTests.uas
			// Within 1.25 µas; Skyfield's light time leaves out the Shapiro delay.
			#expect(direction <= 1.5, "\(value.body): \(direction) µas")
			let corrections = PlaceTests.unit(apparent.position.vector) - PlaceTests.unit(astrometric.position.vector)
			let referenceCorrections = PlaceTests.unit(PlaceTests.vector(value.apparent)) - PlaceTests.unit(reference)
			#expect((corrections - referenceCorrections).length * PlaceTests.uas <= 1.5, "\(value.body)")
			let distance = (astrometric.position.vector.length - reference.length) / speedOfLightAstronomicalUnitsPerDay
			#expect(abs(astrometric.lightTime.inDays - value.lightTime - distance) * secondsPerDay <= 2e-4, "\(value.body)")
		}
	}

	@Test func instantsOutsideTheCoverageThrow() throws {
		let ephemeris = try JPLEphemeris(file: Self.excerpt)
		for seconds in [813_000_000.0, 817_000_000] {
			#expect(throws: EphemerisError.outsideCoverage) {
				try ephemeris.state(of: .moon, relativeTo: .earth, at: Self.instant(seconds))
			}
		}
		let spk = try SPKEphemeris(files: [Self.excerpt])
		#expect(throws: EphemerisError.outsideCoverage) {
			try spk.state(of: .moon, relativeTo: .earth, at: Self.instant(817_000_000))
		}
	}

	@Test func aLaterFileTakesPrecedence() throws {
		// A Sun fixed at (1, 2, 3) km from the barycenter for 2,000 s
		let seconds = 815_000_000.0
		let sun = SPKKernelTests.Segment(target: 10, center: 0, start: seconds - 1_000, end: seconds + 1_000, words: [seconds, 1_000, 1, 0, 2, 0, 3, 0, seconds - 1_000, 2_000, 8, 1])
		let override = try SPKFile(bytes: SPKKernelTests.spk(segments: [sun]))
		let ephemeris = try SPKEphemeris(files: [Self.excerpt, override])
		let state = try ephemeris.state(of: .sun, relativeTo: .solarSystemBarycenter, at: Self.instant(seconds))
		#expect((state.position.vector * kilometersPerAstronomicalUnit - Vector3(1, 2, 3)).length < 1e-9)
		#expect(state.velocity.vector == .zero)
		// Outside the later file's segment, the earlier file's
		let later = seconds + 10_000
		Self.expect(try ephemeris.state(of: .sun, relativeTo: .solarSystemBarycenter, at: Self.instant(later)), matches: SPKSegmentIndex(files: [Self.excerpt]).state(of: 10, relativeTo: 0, at: later)!, "Sun")
		// In the other order, the excerpt's
		let reversed = try SPKEphemeris(files: [override, Self.excerpt])
		#expect(try reversed.state(of: .sun, relativeTo: .solarSystemBarycenter, at: Self.instant(seconds)).position.vector.length > 1e-4)
	}

	@Test func filesMissingABodyThrow() throws {
		let sun = SPKKernelTests.Segment(target: 10, center: 0, start: -1_000, end: 1_000, words: [0, 1_000, 1, 0, 2, 0, 3, 0, -1_000, 2_000, 8, 1])
		let file = try SPKFile(bytes: SPKKernelTests.spk(segments: [sun]))
		#expect(throws: SPKError.missingBody(naifID: 199)) { try JPLEphemeris(file: file) }
		#expect(throws: SPKError.missingBody(naifID: 399)) { try SPKEphemeris(files: [file]) }
		#expect(throws: SPKError.missingBody(naifID: 399)) { try SPKEphemeris(files: []) }
		#expect(throws: SPKError.cannotOpenFile(errno: 2)) { try JPLEphemeris(contentsOf: "/nonexistent/de440.bsp") }
	}
}
