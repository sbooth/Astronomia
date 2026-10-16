//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Observed and predicted UT1 - UTC from the IERS.
///
/// The IERS publishes UT1 - UTC at 0h UTC each day. UT1 - UTC jumps by a second at every
/// leap second, so the table converts each value to ΔT = TT - UT1, which is continuous, and
/// interpolates that instead. Building a table therefore needs the leap seconds in effect.
///
/// Values between entries are interpolated linearly in TT. For daily data this is accurate to
/// about 50 µs. Gaps between entries are interpolated across.
///
/// To build a table from data compiled into an app, rather than parsing a file at run time,
/// generate its entries with `Scripts/generate-timescale-data.py finals` and pass them to
/// ``init(entries:leapSecondTable:)``.
///
/// - SeeAlso: [IERS Rapid Service/Prediction Center](https://maia.usno.navy.mil)
public struct EarthOrientationTable: Hashable, Sendable {
	/// UT1 - UTC at 0h UTC on a day.
	public struct Entry: Hashable, Sendable {
		/// The Julian day number of the UTC day, whose midnight the value applies to.
		public let utcDay: JulianDayNumber
		/// UT1 - UTC, in seconds.
		public let ut1MinusUTC: Double
		/// Whether the value is a prediction rather than an observation.
		public let isPredicted: Bool

		/// Creates an entry.
		///
		/// - Parameters:
		///   - utcDay: The Julian day number of the UTC day.
		///   - ut1MinusUTC: UT1 - UTC at 0h UTC, in seconds.
		///   - isPredicted: Whether the value is a prediction.
		public init(utcDay: JulianDayNumber, ut1MinusUTC: Double, isPredicted: Bool = false) {
			self.utcDay = utcDay
			self.ut1MinusUTC = ut1MinusUTC
			self.isPredicted = isPredicted
		}
	}

	/// ΔT at the TT instant of an entry.
	struct Sample: Hashable, Sendable {
		let tt: JulianDate
		let deltaT: Double
		let isPredicted: Bool
	}

	/// The entries, in increasing order of date.
	public let entries: [Entry]
	/// The entries as ΔT at their TT instants.
	let samples: [Sample]

	/// Creates a table from entries of UT1 - UTC.
	///
	/// - Parameters:
	///   - entries: At least two entries in strictly increasing order of date, with finite
	///     values of UT1 - UTC smaller than a second in magnitude.
	///   - leapSecondTable: The leap seconds used to convert UT1 - UTC to ΔT.
	/// - Returns: `nil` if the entries are invalid or a date is not covered by
	///   `leapSecondTable`.
	public init?(entries: [Entry], leapSecondTable: LeapSecondTable = .builtIn) {
		guard entries.count >= 2 else { return nil }
		let utc = UTC.Context(leapSecondTable: leapSecondTable, extrapolationPolicy: .allow)

		var samples: [Sample] = []
		samples.reserveCapacity(entries.count)
		var previousDay: JulianDayNumber?
		for entry in entries {
			guard entry.ut1MinusUTC.isFinite, entry.ut1MinusUTC.magnitude < 1 else { return nil }
			if let previousDay, entry.utcDay <= previousDay { return nil }
			previousDay = entry.utcDay

			// TT - UT1 = (TT - TAI) + (TAI - UTC) - (UT1 - UTC), all at 0h UTC.
			guard let day = try? UTCDay(julianDayNumber: entry.utcDay, leapSecondTable: leapSecondTable),
				  let tt = try? UTC.toTT(day.start, context: utc)
			else { return nil }
			let deltaT = TT.offsetFromTAI + day.offsetAtStart - entry.ut1MinusUTC
			samples.append(Sample(tt: tt, deltaT: deltaT, isPredicted: entry.isPredicted))
		}

		self.entries = entries
		self.samples = samples
	}

	/// The TT instants covered by the table.
	public var range: ClosedRange<JulianDate> {
		// Not empty: initialization requires at least two entries.
		samples[0].tt ... samples[samples.count - 1].tt
	}

	/// Returns ΔT = TT - UT1 at the specified TT, interpolated linearly between entries.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: ΔT, in seconds, and whether it depends on a predicted entry, or `nil` if
	///   `tt` is outside ``range``.
	public func deltaTAndPredictionStatus(at tt: JulianDate) -> (seconds: Double, isPredicted: Bool)? {
		guard range.contains(tt) else { return nil }

		// The last sample at or before `tt`.
		var low = 0
		var high = samples.count - 1
		while low < high {
			let mid = (low + high + 1) / 2
			if samples[mid].tt <= tt {
				low = mid
			} else {
				high = mid - 1
			}
		}

		let a = samples[low]
		guard low + 1 < samples.count else { return (a.deltaT, a.isPredicted) }
		let b = samples[low + 1]
		let fraction = days(from: a.tt, to: tt) / days(from: a.tt, to: b.tt)
		return (a.deltaT + fraction * (b.deltaT - a.deltaT), a.isPredicted || b.isPredicted)
	}
}

/// Returns the days from `start` to `end`, for nearby dates within a table.
private func days(from start: JulianDate, to end: JulianDate) -> Double {
	Double(end.julianDayNumber - start.julianDayNumber) + (end.fractionFromNoon - start.fractionFromNoon)
}

extension EarthOrientationTable {
	/// Creates a table from the contents of an IERS `finals2000A` (or `finals`) data file,
	/// using the Bulletin A values of UT1 - UTC.
	///
	/// Rows without a UT1 - UTC value are skipped.
	///
	/// - Parameters:
	///   - text: The contents of the file.
	///   - includePredictions: Whether to include rows flagged as predictions.
	///   - leapSecondTable: The leap seconds used to convert UT1 - UTC to ΔT.
	/// - Returns: `nil` if a row is malformed or the entries fail the checks of
	///   ``init(entries:leapSecondTable:)``.
	public init?(finals2000A text: String, includePredictions: Bool = true, leapSecondTable: LeapSecondTable = .builtIn) {
		/// Returns the 1-based, inclusive columns `range` of `bytes` without spaces.
		func field(_ bytes: [UInt8], _ range: ClosedRange<Int>) -> String {
			String(decoding: bytes[(range.lowerBound - 1) ..< range.upperBound].filter { $0 != UInt8(ascii: " ") }, as: UTF8.self)
		}

		var entries: [Entry] = []
		for line in text.split(whereSeparator: \.isNewline) {
			let bytes = Array(line.utf8)
			// Columns 59-68 hold Bulletin A UT1 - UTC; later rows leave them blank.
			guard bytes.count >= 68 else { continue }
			let value = field(bytes, 59 ... 68)
			guard !value.isEmpty else { continue }

			// Column 58 flags IERS (I) or predicted (P) values.
			let isPredicted = bytes[57] == UInt8(ascii: "P")
			if isPredicted && !includePredictions { continue }

			// Columns 8-15 hold the MJD of 0h UTC, such as 57754.00.
			guard let mjd = Double(field(bytes, 8 ... 15)), let day = Int(exactly: mjd),
				  let ut1MinusUTC = Double(value)
			else { return nil }
			entries.append(Entry(utcDay: day + 2_400_001, ut1MinusUTC: ut1MinusUTC, isPredicted: isPredicted))
		}

		self.init(entries: entries, leapSecondTable: leapSecondTable)
	}
}
