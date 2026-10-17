//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Observed and predicted Earth orientation parameters from the IERS.
///
/// The IERS publishes, for 0h UTC each day, the parameters that orient Earth in space:
/// UT1 - UTC, polar motion (``PolarMotion``), the celestial pole offsets
/// (``CelestialPoleOffsets``), and the excess length of day. Each entry has UT1 - UTC and,
/// where published, the others.
///
/// UT1 - UTC jumps by a second at every leap second, so the table converts each value to
/// ΔT = TT - UT1, which is continuous, and interpolates that instead. Building a table
/// therefore needs the leap seconds in effect.
///
/// Values between entries are interpolated linearly in TT. For daily data this is accurate to
/// about 50 µs in UT1 and a few microarcseconds in polar motion. Gaps between entries are
/// interpolated across. The tidal and libration terms that the IERS Conventions add to
/// interpolated values, up to about 0.5 mas in polar motion and 50 µs in UT1, are not
/// applied.
///
/// To build a table from data compiled into an app, rather than parsing a file at run time,
/// generate its entries with `Scripts/generate-timescale-data.py finals` and pass them to
/// ``init(entries:leapSecondTable:)``.
///
/// - SeeAlso: [IERS Rapid Service/Prediction Center](https://maia.usno.navy.mil)
public struct EarthOrientationTable: Hashable, Sendable {
	/// Earth orientation parameters at 0h UTC on a day.
	public struct Entry: Hashable, Sendable {
		/// The Julian day number of the UTC day, whose midnight the values apply to.
		public let utcDay: JulianDayNumber
		/// UT1 - UTC, in seconds.
		public let ut1MinusUTC: Double
		/// Whether UT1 - UTC is a prediction rather than an observation.
		public let isPredicted: Bool
		/// The polar motion coordinates, if published.
		public let polarMotion: PolarMotion?
		/// The celestial pole offsets, if published.
		public let celestialPoleOffsets: CelestialPoleOffsets?
		/// The excess of the length of day over 86,400 s, in seconds, if published.
		///
		/// It is derived with UT1 - UTC, so ``isPredicted`` applies to it too.
		public let excessLengthOfDay: Double?

		/// Creates an entry.
		///
		/// - Parameters:
		///   - utcDay: The Julian day number of the UTC day.
		///   - ut1MinusUTC: UT1 - UTC at 0h UTC, in seconds.
		///   - isPredicted: Whether UT1 - UTC is a prediction.
		///   - polarMotion: The polar motion coordinates, if published.
		///   - celestialPoleOffsets: The celestial pole offsets, if published.
		///   - excessLengthOfDay: The excess of the length of day over 86,400 s, in seconds,
		///     if published.
		public init(
			utcDay: JulianDayNumber,
			ut1MinusUTC: Double,
			isPredicted: Bool = false,
			polarMotion: PolarMotion? = nil,
			celestialPoleOffsets: CelestialPoleOffsets? = nil,
			excessLengthOfDay: Double? = nil
		) {
			self.utcDay = utcDay
			self.ut1MinusUTC = ut1MinusUTC
			self.isPredicted = isPredicted
			self.polarMotion = polarMotion
			self.celestialPoleOffsets = celestialPoleOffsets
			self.excessLengthOfDay = excessLengthOfDay
		}

		/// Whether every published value is finite.
		var isFinite: Bool {
			guard ut1MinusUTC.isFinite else { return false }
			if let polarMotion, !polarMotion.x.radians.isFinite || !polarMotion.y.radians.isFinite {
				return false
			}
			if let celestialPoleOffsets, !celestialPoleOffsets.dX.radians.isFinite || !celestialPoleOffsets.dY.radians.isFinite {
				return false
			}
			if let excessLengthOfDay, !excessLengthOfDay.isFinite {
				return false
			}
			return true
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

	/// Creates a table from entries of Earth orientation parameters.
	///
	/// - Parameters:
	///   - entries: At least two entries in strictly increasing order of date, with finite
	///     values and UT1 - UTC smaller than a second in magnitude.
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
			guard entry.isFinite, entry.ut1MinusUTC.magnitude < 1 else { return nil }
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

	/// The TT dates covered by the table, from the first entry to the last.
	public var coverage: ClosedRange<JulianDate> {
		// Not empty: initialization requires at least two entries.
		samples[0].tt ... samples[samples.count - 1].tt
	}

	/// Returns ΔT = TT - UT1 at the specified TT, interpolated linearly between entries.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: ΔT, in seconds, and whether it depends on a predicted entry, or `nil` if
	///   `tt` is outside ``coverage``.
	public func deltaTAndPredictionStatus(at tt: JulianDate) -> (seconds: Double, isPredicted: Bool)? {
		guard let span = bracket(tt) else { return nil }
		let a = samples[span.a]
		let b = samples[span.b]
		return (a.deltaT + span.fraction * (b.deltaT - a.deltaT), a.isPredicted || b.isPredicted)
	}

	/// Returns the polar motion coordinates at the specified TT, interpolated linearly between
	/// entries.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: The coordinates, predicted if either entry they depend on is, or `nil` if
	///   `tt` is outside ``coverage`` or an entry it depends on has no coordinates.
	public func polarMotion(at tt: JulianDate) -> PolarMotion? {
		guard let span = bracket(tt),
			  let pa = entries[span.a].polarMotion, let pb = entries[span.b].polarMotion
		else { return nil }
		return PolarMotion(
			x: pa.x + (pb.x - pa.x) * span.fraction,
			y: pa.y + (pb.y - pa.y) * span.fraction,
			isPredicted: pa.isPredicted || pb.isPredicted
		)
	}

	/// Returns the celestial pole offsets at the specified TT, interpolated linearly between
	/// entries.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: The offsets, predicted if either entry they depend on is, or `nil` if `tt` is
	///   outside ``coverage`` or an entry it depends on has no offsets.
	public func celestialPoleOffsets(at tt: JulianDate) -> CelestialPoleOffsets? {
		guard let span = bracket(tt),
			  let oa = entries[span.a].celestialPoleOffsets, let ob = entries[span.b].celestialPoleOffsets
		else { return nil }
		return CelestialPoleOffsets(
			dX: oa.dX + (ob.dX - oa.dX) * span.fraction,
			dY: oa.dY + (ob.dY - oa.dY) * span.fraction,
			isPredicted: oa.isPredicted || ob.isPredicted
		)
	}

	/// Returns the excess of the length of day over 86,400 s at the specified TT, interpolated
	/// linearly between entries.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: The excess length of day, in seconds, or `nil` if `tt` is outside ``coverage``
	///   or an entry it depends on has no value.
	public func excessLengthOfDay(at tt: JulianDate) -> Double? {
		guard let span = bracket(tt),
			  let la = entries[span.a].excessLengthOfDay, let lb = entries[span.b].excessLengthOfDay
		else { return nil }
		return la + span.fraction * (lb - la)
	}

	/// Returns the indices of the entries on either side of `tt` and the fraction of the way
	/// from the first to the second, or `nil` if `tt` is outside ``coverage``. When `tt` is at an
	/// entry, both indices are that entry's, so values there need no neighbor.
	private func bracket(_ tt: JulianDate) -> (a: Int, b: Int, fraction: Double)? {
		guard coverage.contains(tt) else { return nil }

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
		guard a.tt != tt, low + 1 < samples.count else { return (low, low, 0) }
		let b = samples[low + 1]
		return (low, low + 1, days(from: a.tt, to: tt) / days(from: a.tt, to: b.tt))
	}
}

/// Returns the days from `start` to `end`, for nearby dates within a table.
private func days(from start: JulianDate, to end: JulianDate) -> Double {
	Double(end.julianDayNumber - start.julianDayNumber) + (end.fractionFromNoon - start.fractionFromNoon)
}

extension EarthOrientationTable {
	/// Creates a table from the contents of an IERS `finals2000A` data file, using the
	/// Bulletin A values.
	///
	/// Rows without a UT1 - UTC value are skipped. Polar motion, the celestial pole offsets,
	/// and the excess length of day are read where present, each with its own prediction flag;
	/// the excess length of day shares the flag of UT1 - UTC.
	///
	/// - Important: In the older IAU 1980 `finals` files, the columns of dX and dY hold the
	///   nutation offsets dψ and dε instead, which this initializer would read as dX and dY.
	///   UT1 - UTC and polar motion are in the same columns of both.
	///
	/// - Parameters:
	///   - text: The contents of the file.
	///   - includePredictions: Whether to include predicted values. Without them, rows whose
	///     UT1 - UTC is predicted are skipped, and other predicted values are left out.
	///   - leapSecondTable: The leap seconds used to convert UT1 - UTC to ΔT.
	/// - Returns: `nil` if a row is malformed or the entries fail the checks of
	///   ``init(entries:leapSecondTable:)``.
	public init?(finals2000A text: String, includePredictions: Bool = true, leapSecondTable: LeapSecondTable = .builtIn) {
		/// Returns the 1-based, inclusive columns `range` of `bytes` without spaces, or an empty
		/// string if the row is shorter.
		func field(_ bytes: [UInt8], _ range: ClosedRange<Int>) -> String {
			guard bytes.count >= range.upperBound else { return "" }
			return String(decoding: bytes[(range.lowerBound - 1) ..< range.upperBound].filter { $0 != UInt8(ascii: " ") }, as: UTF8.self)
		}

		/// Whether the 1-based column `column` of `bytes` flags a prediction (P), not an IERS
		/// value (I).
		func isPrediction(_ bytes: [UInt8], _ column: Int) -> Bool {
			bytes.count >= column && bytes[column - 1] == UInt8(ascii: "P")
		}

		/// The values of the 1-based columns `first` and `second`, or `.some(nil)` if both are
		/// blank. Returns `nil`, a malformed row, if only one is blank or either is not a number.
		func pair(_ bytes: [UInt8], _ first: ClosedRange<Int>, _ second: ClosedRange<Int>) -> (Double, Double)?? {
			let a = field(bytes, first)
			let b = field(bytes, second)
			if a.isEmpty && b.isEmpty { return .some(nil) }
			guard let x = Double(a), let y = Double(b) else { return nil }
			return (x, y)
		}

		var entries: [Entry] = []
		for line in text.split(whereSeparator: \.isNewline) {
			let bytes = Array(line.utf8)
			// Columns 59-68 hold Bulletin A UT1 - UTC; later rows leave them blank.
			let value = field(bytes, 59 ... 68)
			guard !value.isEmpty else { continue }

			// Column 58 flags UT1 - UTC as an IERS (I) or predicted (P) value.
			let isPredicted = isPrediction(bytes, 58)
			if isPredicted && !includePredictions { continue }

			// Columns 8-15 hold the MJD of 0h UTC, such as 57754.00.
			guard let mjd = Double(field(bytes, 8 ... 15)), let day = Int(exactly: mjd),
				  let ut1MinusUTC = Double(value)
			else { return nil }

			// Columns 19-27 and 38-46 hold x_p and y_p in arcseconds, flagged in column 17.
			guard let pole = pair(bytes, 19 ... 27, 38 ... 46) else { return nil }
			var polarMotion: PolarMotion?
			if let pole, includePredictions || !isPrediction(bytes, 17) {
				polarMotion = PolarMotion(x: Angle(arcseconds: pole.0), y: Angle(arcseconds: pole.1), isPredicted: isPrediction(bytes, 17))
			}

			// Columns 98-106 and 117-125 hold dX and dY in milliarcseconds, flagged in column 96.
			guard let offsets = pair(bytes, 98 ... 106, 117 ... 125) else { return nil }
			var celestialPoleOffsets: CelestialPoleOffsets?
			if let offsets, includePredictions || !isPrediction(bytes, 96) {
				celestialPoleOffsets = CelestialPoleOffsets(dX: Angle(milliarcseconds: offsets.0), dY: Angle(milliarcseconds: offsets.1), isPredicted: isPrediction(bytes, 96))
			}

			// Columns 80-86 hold the excess length of day in milliseconds.
			let lod = field(bytes, 80 ... 86)
			var excessLengthOfDay: Double?
			if !lod.isEmpty {
				guard let milliseconds = Double(lod) else { return nil }
				excessLengthOfDay = milliseconds / 1000
			}

			entries.append(Entry(
				utcDay: day + 2_400_001,
				ut1MinusUTC: ut1MinusUTC,
				isPredicted: isPredicted,
				polarMotion: polarMotion,
				celestialPoleOffsets: celestialPoleOffsets,
				excessLengthOfDay: excessLengthOfDay
			))
		}

		self.init(entries: entries, leapSecondTable: leapSecondTable)
	}
}
