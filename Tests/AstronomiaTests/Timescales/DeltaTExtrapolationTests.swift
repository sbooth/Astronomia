//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// ΔT from Espenak & Meeus (2006), offset to join the historic table at its nearer end, as in
/// the default UT1 context outside the table.
func historicJoinedModel(_ decimalYear: Double) -> Double {
	let model = DeltaTModel.espenakMeeus2006
	let end = decimalYear < 1657 ? DeltaTTable.historic.lowerEnd : DeltaTTable.historic.upperEnd
	return model.deltaT(decimalYear: decimalYear) + (end.deltaT - model.deltaT(decimalYear: end.tt.decimalYear))
}

@Suite struct DeltaTExtrapolationTests {
	typealias Entry = DeltaTTable.Entry

	/// ΔT rising 2 s per year at the start and 1 s per year at the end.
	static func table() throws -> DeltaTTable {
		try #require(DeltaTTable(entries: [
			Entry(decimalYear: 2000, deltaT: 60),
			Entry(decimalYear: 2001, deltaT: 62),
			Entry(decimalYear: 2002, deltaT: 63),
		]))
	}

	/// Returns ΔT from `source` at a decimal year, and the Julian Date of that decimal year.
	static func deltaT(_ source: some DeltaTSource, _ decimalYear: Double) throws -> (deltaT: Double?, tt: JulianDate) {
		let tt = try JulianDate(decimalYear: decimalYear)
		return (source.deltaT(at: tt), tt)
	}

	@Test func endpoints() throws {
		let table = try Self.table()
		// Rates are per Julian year of 365.25 days: 2000 has 366 days and 2001 has 365.
		#expect(try table.lowerEnd.tt == JulianDate(decimalYear: 2000))
		#expect(table.lowerEnd.deltaT == 60)
		#expect(abs(table.lowerEnd.rate - 2 * 365.25 / 366) <= 1e-12)
		#expect(try table.upperEnd.tt == JulianDate(decimalYear: 2002))
		#expect(table.upperEnd.deltaT == 63)
		#expect(abs(table.upperEnd.rate - 365.25 / 365) <= 1e-12)

		// 1657.0 to 1657.5 is 182.5 days
		let historic = DeltaTTable.historic
		#expect(try historic.lowerEnd.tt == JulianDate(decimalYear: 1657))
		#expect(historic.lowerEnd.deltaT == 44)
		#expect(abs(historic.lowerEnd.rate - (-365.25 / 182.5)) <= 1e-12)
		#expect(try historic.upperEnd.tt == JulianDate(decimalYear: 1984.5))
		#expect(historic.upperEnd.deltaT == 54.087)
	}

	@Test func rejectsDecimalYearsWithoutJulianDates() {
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: 60), Entry(decimalYear: 1e300, deltaT: 62)]) == nil)
	}

	@Test func withinSpanUsesSource() throws {
		let source = DeltaTExtrapolation(try Self.table(), before: .constant, after: .constant)
		let (value, _) = try Self.deltaT(source, 2001)
		#expect(try abs(#require(value) - 62) <= 1e-6)
	}

	@Test func notExtendedByDefault() throws {
		let source = DeltaTExtrapolation(try Self.table())
		#expect(try Self.deltaT(source, 1999).deltaT == nil)
		#expect(try Self.deltaT(source, 2003).deltaT == nil)

		let beforeOnly = DeltaTExtrapolation(try Self.table(), before: .constant)
		#expect(try Self.deltaT(beforeOnly, 1999).deltaT == 60)
		#expect(try Self.deltaT(beforeOnly, 2003).deltaT == nil)
	}

	@Test func constant() throws {
		let source = DeltaTExtrapolation(try Self.table(), before: .constant, after: .constant)
		#expect(try Self.deltaT(source, 1990).deltaT == 60)
		#expect(try Self.deltaT(source, 2010).deltaT == 63)
	}

	@Test func linear() throws {
		let source = DeltaTExtrapolation(try Self.table(), before: .linear, after: .linear)
		let table = try Self.table()
		// 1998-01-01 is 730 days before 2000-01-01, at 2 s per 366 days
		let (before, beforeTT) = try Self.deltaT(source, 1998)
		#expect(try abs(#require(before) - (60 + table.lowerEnd.rate * table.lowerEnd.tt.interval(to: beforeTT).inDays / 365.25)) <= 1e-9)
		#expect(try abs(#require(before) - (60 - 2.0 * 730 / 366)) <= 1e-9)
		// 2005-01-01 is 1096 days after 2002-01-01, at 1 s per 365 days
		let (after, afterTT) = try Self.deltaT(source, 2005)
		#expect(try abs(#require(after) - (63 + table.upperEnd.rate * table.upperEnd.tt.interval(to: afterTT).inDays / 365.25)) <= 1e-9)
		#expect(try abs(#require(after) - (63 + 1096.0 / 365)) <= 1e-9)
	}

	@Test func model() throws {
		let model = DeltaTModel.espenakMeeus2006
		let source = DeltaTExtrapolation(try Self.table(), before: .model(model), after: .model(model))
		let (after, afterTT) = try Self.deltaT(source, 2010)
		#expect(try abs(#require(after) - (63 + (model.deltaT(decimalYear: afterTT.decimalYear) - model.deltaT(decimalYear: 2002)))) <= 1e-9)
		let (before, beforeTT) = try Self.deltaT(source, 1990)
		#expect(try abs(#require(before) - (60 + (model.deltaT(decimalYear: beforeTT.decimalYear) - model.deltaT(decimalYear: 2000)))) <= 1e-9)
	}

	@Test func limit() throws {
		let source = DeltaTExtrapolation(try Self.table(), before: .constant, after: .constant, limit: 1)
		#expect(try Self.deltaT(source, 2002.5).deltaT == 63)
		#expect(try Self.deltaT(source, 2003.5).deltaT == nil)
		#expect(try Self.deltaT(source, 1999.5).deltaT == 60)
		#expect(try Self.deltaT(source, 1998.5).deltaT == nil)
	}

	@Test(arguments: [1657.0, 1984.5])
	func defaultContextIsContinuousAtHistoricTable(decimalYear: Double) throws {
		// A thousandth of a year either side of the end changes ΔT by milliseconds, not by the
		// 3.7 s or 0.04 s between the raw model and the table.
		let inside = try UT1.deltaT(at: JulianDate(decimalYear: decimalYear + (decimalYear < 1700 ? 0.001 : -0.001)), context: UT1.defaultContext)
		let outside = try UT1.deltaT(at: JulianDate(decimalYear: decimalYear + (decimalYear < 1700 ? -0.001 : 0.001)), context: UT1.defaultContext)
		#expect(abs(inside - outside) <= 0.01)
	}

	@Test func observationsContinueAlongModel() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let end = table.upperEnd
		let context = UT1.Context(earthOrientation: table)

		// A day after the last observation, ΔT is close to it, not the model's value
		let nextDay = try table.range.upperBound.adding(days: 1)
		let joined = try UT1.deltaT(at: nextDay, context: context)
		#expect(abs(joined - end.deltaT) <= 0.01)
		#expect(abs(joined - DeltaTModel.espenakMeeus2006.deltaT(decimalYear: nextDay.decimalYear)) > 1)

		// Later, ΔT follows the model's change since the last observation
		let later = try table.range.upperBound.adding(days: 365)
		let model = DeltaTModel.espenakMeeus2006
		let expected = end.deltaT + (model.deltaT(decimalYear: later.decimalYear) - model.deltaT(decimalYear: end.tt.decimalYear))
		#expect(try abs(UT1.deltaT(at: later, context: context) - expected) <= 1e-9)
	}
}
