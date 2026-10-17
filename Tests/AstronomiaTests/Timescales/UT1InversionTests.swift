//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Converting UT1 to TT finds the TT within a source's coverage, including at its ends.
@Suite struct UT1InversionTests {
	typealias Entry = DeltaTTable.Entry

	/// A table covering `year` to the following year, with ΔT from `start` to `end` seconds.
	static func table(year: Double = 2000, _ start: Double, _ end: Double) throws -> DeltaTTable {
		try #require(DeltaTTable(entries: [
			Entry(decimalYear: year, deltaT: start),
			Entry(decimalYear: year + 1, deltaT: end),
		]))
	}

	/// Expects `tt` to convert to UT1 and back to within the tolerance.
	static func expectUT1RoundTrip(_ tt: JulianDate, _ context: UT1.Context, sourceLocation: SourceLocation = #_sourceLocation) throws {
		let ut1 = try UT1.fromTT(tt, context: context)
		let back = try UT1.toTT(ut1, context: context)
		#expect(back.isApproximatelyEqual(to: tt, toleranceSeconds: timescaleTolerance), "\(tt)", sourceLocation: sourceLocation)
	}

	@Test func roundTripAtCoverageEnds() throws {
		// ΔT constant, as in the review, and rising 10 s over the year
		for (start, end) in [(64.0, 64.0), (60, 70)] {
			let table = try Self.table(start, end)
			let context = UT1.Context(deltaT: table)
			let lower = table.coverage.lowerBound
			let upper = table.coverage.upperBound
			let dates = try [
				lower, lower.adding(seconds: 1e-6), lower.adding(seconds: 1e-3), lower.adding(seconds: 1),
				upper.adding(seconds: -1), upper.adding(seconds: -1e-6), upper,
			]
			for tt in dates {
				try Self.expectUT1RoundTrip(tt, context)
			}
		}
	}

	@Test func firstEntryWithoutModel() throws {
		// The review's case: the UT1 of the first entry is ΔT before the table starts.
		let table = try Self.table(64, 64)
		let context = UT1.Context(deltaT: table)
		let ut1 = try UT1.fromTT(table.coverage.lowerBound, context: context)
		#expect(try UT1.toTT(ut1, context: context).isApproximatelyEqual(to: table.coverage.lowerBound, toleranceSeconds: timescaleTolerance))
		#expect(table.deltaT(atUT1: ut1) == 64)
	}

	@Test func outsideCoverage() throws {
		let table = try Self.table(64, 64)
		let context = UT1.Context(deltaT: table)
		// The table covers UT1 from 64 s before its first entry to 64 s before its last.
		let early = try table.coverage.lowerBound.adding(seconds: -65)
		let late = try table.coverage.upperBound.adding(seconds: -63)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) { try UT1.toTT(early, context: context) }
		#expect(throws: TimescaleConversionError.deltaTUnavailable) { try UT1.toTT(late, context: context) }
	}

	@Test func earthOrientationEnds() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let context = UT1.Context(deltaT: table)
		try Self.expectUT1RoundTrip(table.coverage.lowerBound, context)
		try Self.expectUT1RoundTrip(table.coverage.upperBound, context)
	}

	@Test func gapBetweenSources() throws {
		let first = try Self.table(64, 65)
		let second = try Self.table(year: 2002, 66, 67)
		let context = UT1.Context(deltaT: DeltaTSourceList([first, second]))
		// The UT1 of the second table's start is 66 s into the gap, before the table.
		try Self.expectUT1RoundTrip(second.coverage.lowerBound, context)
		try Self.expectUT1RoundTrip(first.coverage.upperBound, context)

		let inGap = try JulianDate(decimalYear: 2001.5)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) { try UT1.toTT(inGap, context: context) }
	}

	@Test func extrapolationLimit() throws {
		let table = try Self.table(60, 70)
		let earliest = try table.coverage.lowerBound.adding(days: -0.5 * JulianDate.daysPerJulianYear)
		let latest = try table.coverage.upperBound.adding(days: 0.5 * JulianDate.daysPerJulianYear)
		let source = try DeltaTSourceList([
			table,
			ConstantDeltaTExtrapolation(before: table, from: earliest),
			LinearDeltaTExtrapolation(after: table, through: latest),
		])
		let context = UT1.Context(deltaT: source)
		let dates = try [
			earliest, earliest.adding(seconds: 1), table.coverage.lowerBound.adding(seconds: -1), table.coverage.lowerBound,
			table.coverage.upperBound, table.coverage.upperBound.adding(seconds: 1), latest.adding(seconds: -1), latest,
		]
		for tt in dates {
			try Self.expectUT1RoundTrip(tt, context)
		}

		// ΔT is 60 s before the table, so UT1 is covered from 60 s before `earliest`.
		let beforeLimit = try earliest.adding(seconds: -61)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) { try UT1.toTT(beforeLimit, context: context) }
		let afterLimit = try latest.adding(seconds: 1)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) { try UT1.toTT(afterLimit, context: context) }
	}

	@Test func extrapolationFollowingModel() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let context = UT1.Context.continuous(earthOrientation: table, deltaTTable: nil, model: .espenakMeeus2006)
		let end = table.coverage.upperBound
		for tt in try [end, end.adding(seconds: 1), end.adding(days: 365)] {
			try Self.expectUT1RoundTrip(tt, context)
		}
	}

	@Test func customSource() throws {
		/// A source with stated coverage and the default inverse.
		struct Custom: DeltaTSource {
			let table: DeltaTTable
			var coverage: ClosedRange<JulianDate> { table.coverage }
			func deltaT(at tt: JulianDate) -> Double? { table.deltaT(at: tt) }
		}

		let table = try Self.table(64, 64)
		let ut1 = try table.coverage.lowerBound.adding(seconds: -64)
		#expect(Custom(table: table).deltaT(atUT1: ut1) == 64)

		// A function with stated coverage iterates within it.
		let covered = DeltaTFunction(coverage: table.coverage) { table.deltaT(at: $0) }
		#expect(covered.deltaT(atUT1: ut1) == 64)

		// Without stated coverage, the iteration starts before the table and finds no ΔT.
		let uncovered = DeltaTFunction { table.deltaT(at: $0) }
		#expect(uncovered.deltaT(atUT1: ut1) == nil)
	}

	@Test func joinedModelEnds() throws {
		// The join starts at the end of the table, with the table's ΔT of 65 s.
		let table = try Self.table(64, 65)
		let model = DeltaTModel.espenakMeeus2006
		let after = try JoinedDeltaTSource(model, after: table)
		let end = table.coverage.upperBound
		let joinDeltaT = try #require(after.deltaT(at: end))
		let ut1 = try end.adding(seconds: -joinDeltaT)
		#expect(try abs(#require(after.deltaT(atUT1: ut1)) - 65) <= 1e-9)
		// A year later ΔT has changed as the model's does, by well under a second
		#expect(try abs(#require(after.deltaT(atUT1: ut1.adding(days: 365))) - 65) <= 1)
		// At the join, ΔT is the table's exactly, so the two meet without a gap
		#expect(after.deltaT(at: end) == table.deltaT(at: end))
		// Before the join, the join gives no ΔT
		#expect(try after.deltaT(atUT1: ut1.adding(seconds: -1)) == nil)
	}

	@Test func inverseInterpolationWithinSegment() throws {
		// Halfway through a table rising from 60 s to 70 s, ΔT is 65 s.
		let table = try Self.table(60, 70)
		let span = try table.coverage.lowerBound.interval(to: table.coverage.upperBound).inSeconds
		let middle = try table.coverage.lowerBound.adding(seconds: span / 2)
		let ut1 = try middle.adding(seconds: -65)
		#expect(try abs(#require(table.deltaT(atUT1: ut1)) - 65) <= 1e-9)

		// At an entry's UT1, the entry's value exactly
		let last = try table.coverage.upperBound.adding(seconds: -70)
		#expect(table.deltaT(atUT1: last) == 70)
	}

	@Test func inverseInterpolationMatchesIteration() throws {
		let table = try Self.table(60, 70)
		let earthOrientation = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let sources: [any DeltaTSource] = [table, earthOrientation]
		for source in sources {
			let coverage = source.coverage
			let span = try coverage.lowerBound.interval(to: coverage.upperBound).inSeconds
			for fraction in [0, 0.1, 0.25, 0.5, 0.75, 0.9, 1] {
				// Adding the whole span can round past the end, so keep the date within coverage.
				let tt = try coverage.lowerBound.adding(seconds: fraction * span).clamped(to: coverage)
				let deltaT = try #require(source.deltaT(at: tt))
				let ut1 = try tt.adding(seconds: -deltaT)
				let exact = try #require(source.deltaT(atUT1: ut1))
				let iterated = try #require(source.iteratedDeltaT(atUT1: ut1, within: coverage))
				#expect(abs(exact - iterated) <= 1e-9, "\(fraction)")
			}
		}
	}

	@Test func nonFiniteDeltaT() throws {
		let ut1 = try JulianDate(decimalYear: 2026)
		#expect(throws: TimescaleConversionError.nonFiniteValue) {
			try UT1.toTT(ut1, context: UT1.Context(deltaT: DeltaTFunction.constant(.nan)))
		}

		// A non-finite ΔT at an end of the coverage leaves the UT1 dates covered unknown, which
		// is not the fault of the date converted.
		let start = try JulianDate(decimalYear: 2000)
		let end = try JulianDate(decimalYear: 2030)
		let badEnd = DeltaTFunction(coverage: start ... end) { $0 == end ? Double.nan : 64 }
		let nearStart = try start.adding(seconds: -64)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try UT1.toTT(nearStart, context: UT1.Context(deltaT: badEnd))
		}
	}

	@Test func tableChangingFasterThanTT() throws {
		let start = try JulianDate(decimalYear: 2000)
		// ΔT rising 11 s in 10 s gives some UT1 dates several TTs and others none; falling as
		// fast, the iteration would not converge.
		let later = try start.adding(seconds: 10)
		#expect(DeltaTTable(entries: [Entry(tt: start, deltaT: 0), Entry(tt: later, deltaT: 11)]) == nil)
		#expect(DeltaTTable(entries: [Entry(tt: start, deltaT: 0), Entry(tt: later, deltaT: -11)]) == nil)
		#expect(DeltaTTable(entries: [Entry(tt: start, deltaT: 0), Entry(tt: later, deltaT: 9.5)]) != nil)
	}
}
