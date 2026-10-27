//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import Testing
@testable import Astronomia

@Suite struct SPKTypesTests {
	/// Returns the path of a fixture SPK file.
	static func path(_ name: String) -> String {
		guard let url = Bundle.module.url(forResource: name, withExtension: "bsp", subdirectory: "Fixtures") else {
			fatalError("Missing Fixtures/\(name).bsp")
		}
		return url.path
	}

	/// The segments of types 8, 9, 12, and 13, from CSPICE's writers.
	static let types = try! SPKFile(contentsOf: path("SPKTypes"))
	/// The segments of types 1 and 21.
	static let differences = try! SPKFile(contentsOf: path("SPKDifferences"))

	/// Expects a state to match CSPICE's.
	static func expect(_ state: (position: Vector3, velocity: Vector3), matches row: (body: Int, seconds: Double, position: [Double], velocity: [Double]), _ comment: Comment) {
		let position = Vector3(row.position[0], row.position[1], row.position[2])
		let velocity = Vector3(row.velocity[0], row.velocity[1], row.velocity[2])
		#expect((state.position - position).length <= 1e-14 * position.length, comment)
		#expect((state.velocity - velocity).length <= 1e-13 * velocity.length, comment)
	}

	@Test func theSegmentsAreSupported() {
		#expect(Self.types.segments.map { $0.type } == [8, 9, 12, 13, 9, 8, 9, 12, 13])
		#expect(Self.types.segments.map { $0.frame } == [1, 1, 1, 1, 17, 1, 1, 1, 1])
		#expect(Self.differences.segments.map { $0.type } == [1, 21])
		#expect((Self.types.segments + Self.differences.segments).allSatisfy { $0.isSupported })
	}

	@Test func statesMatchCSPICE() throws {
		#expect(cspiceSPKTypeStates.count == 198)
		for row in cspiceSPKTypeStates {
			let file = row.body == 1001 || row.body == 1021 ? Self.differences : Self.types
			let segment = try #require(file.kernel.segments.first { $0.target == row.body })
			Self.expect(file.kernel.state(of: segment, at: row.seconds), matches: row, "\(row.body) at \(row.seconds)")
		}
	}

	@Test func statesJoinOtherFiles() throws {
		// Each body relative to the Sun, and the Sun relative to the solar system barycenter
		// from the DE421 excerpt
		let excerpt = try SPKFile(contentsOf: SPKKernelTests.excerptPath)
		let index = SPKSegmentIndex(files: [excerpt, Self.types, Self.differences])
		for row in cspiceSPKTypeStates where row.seconds <= excerpt.kernel.segments[0].end {
			let state = try #require(index.state(of: row.body, relativeTo: 10, at: row.seconds))
			Self.expect(state, matches: row, "\(row.body) at \(row.seconds)")
			let sun = try #require(index.state(of: 10, relativeTo: 0, at: row.seconds))
			let barycentric = try #require(index.state(of: row.body, relativeTo: 0, at: row.seconds))
			#expect(barycentric.position == state.position + sun.position)
		}
	}

	@Test func damagedDifferenceLinesGiveStatesThatAreNotFinite() throws {
		// A record whose largest integration order exceeds the table's dimension
		let segment = try #require(Self.differences.kernel.segments.first { $0.type == 21 })
		guard case let .differenceLines(data) = segment.data else {
			Issue.record("Not a segment of difference lines")
			return
		}
		var bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: Self.path("SPKDifferences"))))
		let address = data.firstAddress + 4 * data.dimension + 7
		withUnsafeBytes(of: (100.0).bitPattern.littleEndian) { bytes.replaceSubrange((address - 1) * 8 ..< address * 8, with: $0) }
		let damaged = try SPKFile(bytes: bytes)
		let read = try #require(damaged.kernel.segments.first { $0.type == 21 })
		let state = damaged.kernel.state(of: read, at: read.start)
		#expect(!state.position.x.isFinite && !state.velocity.x.isFinite)
	}
}
