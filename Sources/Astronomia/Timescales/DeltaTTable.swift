//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A table of ΔT = TT - UT1 at decimal years.
///
/// Values between entries are interpolated linearly. Decimal years are calendar-based, as
/// returned by ``JulianDate/decimalYear``, and are evaluated in TT; the difference between
/// evaluating in TT and UT1 is negligible for ΔT.
public struct DeltaTTable: Sendable {
	/// ΔT at a decimal year.
	public struct Entry: Hashable, Sendable {
		/// The decimal year.
		public let decimalYear: Double
		/// ΔT = TT - UT1, in seconds.
		public let deltaT: Double
		/// The standard error of ``deltaT``, in seconds, if known.
		public let uncertainty: Double?

		/// Creates an entry.
		///
		/// - Parameters:
		///   - decimalYear: The decimal year.
		///   - deltaT: ΔT = TT - UT1, in seconds.
		///   - uncertainty: The standard error of `deltaT`, in seconds, if known.
		public init(decimalYear: Double, deltaT: Double, uncertainty: Double? = nil) {
			self.decimalYear = decimalYear
			self.deltaT = deltaT
			self.uncertainty = uncertainty
		}
	}

	/// The entries, in increasing order of decimal year.
	public let entries: [Entry]
	/// ΔT and its rate at the first entry, with the rate between the first two entries.
	public let lowerEnd: DeltaTEndpoint
	/// ΔT and its rate at the last entry, with the rate between the last two entries.
	public let upperEnd: DeltaTEndpoint

	/// Creates a table.
	///
	/// - Parameter entries: At least two entries in strictly increasing order of decimal year,
	///   with finite values of ΔT and finite, nonnegative uncertainties. The decimal years of
	///   the first two and last two entries must be representable as Julian Dates.
	/// - Returns: `nil` if the entries are invalid.
	public init?(entries: [Entry]) {
		guard entries.count >= 2 else { return nil }

		for (index, entry) in entries.enumerated() {
			guard entry.decimalYear.isFinite, entry.deltaT.isFinite else { return nil }
			if let uncertainty = entry.uncertainty {
				guard uncertainty.isFinite, uncertainty >= 0 else { return nil }
			}
			if index > 0, entry.decimalYear <= entries[index - 1].decimalYear { return nil }
		}
		guard Self.endpoints(entries) != nil else { return nil }

		self.init(uncheckedEntries: entries)
	}

	/// Creates a table from entries already known to be valid.
	///
	/// - Precondition: `entries` satisfy the requirements of ``init(entries:)``.
	init(uncheckedEntries entries: [Entry]) {
		guard let endpoints = Self.endpoints(entries) else {
			preconditionFailure("Invalid ΔT table entries")
		}
		self.entries = entries
		self.lowerEnd = endpoints.lower
		self.upperEnd = endpoints.upper
	}

	/// Returns the endpoints of a table with `entries`, or `nil` if a decimal year at either
	/// end cannot be represented as a Julian Date.
	private static func endpoints(_ entries: [Entry]) -> (lower: DeltaTEndpoint, upper: DeltaTEndpoint)? {
		/// Returns the endpoint at `end`, with the rate from `a` to `b`.
		func endpoint(_ a: Entry, _ b: Entry, at end: Entry) -> DeltaTEndpoint? {
			guard let ta = try? JulianDate(decimalYear: a.decimalYear),
				  let tb = try? JulianDate(decimalYear: b.decimalYear)
			else { return nil }
			let tt = end.decimalYear == a.decimalYear ? ta : tb
			return DeltaTEndpoint(tt: tt, deltaT: end.deltaT, rate: (b.deltaT - a.deltaT) / julianYears(from: ta, to: tb))
		}

		let count = entries.count
		guard count >= 2,
			  let lower = endpoint(entries[0], entries[1], at: entries[0]),
			  let upper = endpoint(entries[count - 2], entries[count - 1], at: entries[count - 1])
		else { return nil }
		return (lower, upper)
	}

	/// The decimal years covered by the table.
	public var range: ClosedRange<Double> {
		// Not empty: initialization requires at least two entries.
		entries[0].decimalYear ... entries[entries.count - 1].decimalYear
	}

	/// Returns ΔT = TT - UT1 at the specified decimal year, interpolated linearly between
	/// entries.
	///
	/// - Parameter decimalYear: The decimal year in TT.
	/// - Returns: ΔT and its uncertainty, in seconds, or `nil` if `decimalYear` is outside
	///   ``range``. At an entry, the entry's values. Between entries, the uncertainty is
	///   interpolated the same way, and is `nil` unless both neighboring entries have one.
	public func deltaTAndUncertainty(decimalYear: Double) -> (seconds: Double, uncertainty: Double?)? {
		guard range.contains(decimalYear) else { return nil }

		// The last entry at or before `decimalYear`.
		var low = 0
		var high = entries.count - 1
		while low < high {
			let mid = (low + high + 1) / 2
			if entries[mid].decimalYear <= decimalYear {
				low = mid
			} else {
				high = mid - 1
			}
		}

		let a = entries[low]
		// At an entry, return it exactly, without the next entry's uncertainty
		guard low + 1 < entries.count, a.decimalYear < decimalYear else { return (a.deltaT, a.uncertainty) }
		let b = entries[low + 1]
		let fraction = (decimalYear - a.decimalYear) / (b.decimalYear - a.decimalYear)
		let seconds = a.deltaT + fraction * (b.deltaT - a.deltaT)
		guard let ua = a.uncertainty, let ub = b.uncertainty else { return (seconds, nil) }
		return (seconds, ua + fraction * (ub - ua))
	}

	/// Returns ΔT = TT - UT1 at the specified TT, interpolated linearly between entries.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: ΔT and its uncertainty, in seconds, or `nil` if `tt` is outside ``range``.
	///   The uncertainty is as for ``deltaTAndUncertainty(decimalYear:)``.
	public func deltaTAndUncertainty(at tt: JulianDate) -> (seconds: Double, uncertainty: Double?)? {
		deltaTAndUncertainty(decimalYear: tt.decimalYear)
	}
}

extension DeltaTTable: DeltaTSource {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT, interpolated linearly between
	/// entries, or `nil` if `tt` is outside ``range``.
	public func deltaT(at tt: JulianDate) -> Double? {
		deltaTAndUncertainty(at: tt)?.seconds
	}
}

extension DeltaTTable: Hashable {
	/// Returns `true` if the two tables have the same entries.
	///
	/// - Returns: `true` if both tables have the same entries; otherwise, `false`.
	public static func == (lhs: DeltaTTable, rhs: DeltaTTable) -> Bool {
		lhs.entries == rhs.entries
	}

	/// Hashes the entries into the specified hasher.
	///
	/// - Parameter hasher: The hasher to use when combining the components of this instance.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(entries)
	}
}

extension DeltaTTable {
	/// ΔT at half-year intervals from 1657.0 to 1984.5, from the USNO file
	/// `historic_deltat.data`.
	///
	/// The uncertainty falls from up to 19 s in the 17th century to 3 ms or less from 1956.
	/// A decimal year in the file is taken as calendar-based, so 1657.5 is noon on July 2, 1657;
	/// other readings move a sample by under a day, which changes ΔT by at most a few
	/// milliseconds.
	///
	/// The entries are generated by `Scripts/generate-historic-delta-t.py`.
	///
	/// - SeeAlso: [historic_deltat.data](https://maia.usno.navy.mil/ser7/historic_deltat.data)
	public static let historic = DeltaTTable(uncheckedEntries: historicDeltaTEntries)
}
