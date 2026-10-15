//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A table containing IERS Bulletin C leap second information.
///
/// - SeeAlso: [IERS Bulletin C](https://www.iers.org/iers/en/publications/bulletins/directlinks/bulletin-c-md)
public struct LeapSecondTable: Hashable, Sendable {
	/// An entry from the IERS leap second table.
	public struct Entry: Hashable, Sendable {
		/// The effective Julian day number of the entry, in UTC.
		public let effective: JulianDayNumber
		/// The TAI - UTC offset at the reference day, in seconds.
		public let offset: Double
		/// The reference Julian day number.
		public let reference: JulianDayNumber
		/// The rate of change of the TAI - UTC offset, in seconds per day.
		public let rate: Double

		public init(effective: JulianDayNumber, offset: Double, reference: JulianDayNumber, rate: Double) {
			self.effective = effective
			self.offset = offset
			self.reference = reference
			self.rate = rate
		}
	}

	/// Leap second table entries.
	public let entries: [Entry]
	/// Julian day number of the first UTC day whose length is not yet determined by IERS Bulletin C.
	public let horizon: JulianDayNumber

	/// Creates a leap second table.
	///
	/// A valid table has at least one entry, entries in strictly increasing order of effective
	/// day with finite offsets and rates, a constant TAI - UTC after the last entry, and a
	/// horizon after the last entry. TAI - UTC must stay in the right-open interval
	/// [0, 86,400) s, because converting TAI to UTC assumes UTC is behind TAI by less than a
	/// day.
	///
	/// - Parameters:
	///   - entries: The entries, in increasing order of effective day.
	///   - horizon: The Julian day number of the first UTC day whose length is not yet
	///     determined.
	/// - Throws: A ``ValidationError`` describing the first problem found.
	public init(entries: [Entry], horizon: JulianDayNumber) throws(ValidationError) {
		try Self.validate(entries: entries, horizon: horizon)
		self.init(uncheckedEntries: entries, horizon: horizon)
	}

	/// Creates a leap second table from entries already known to be valid.
	///
	/// - Precondition: `entries` and `horizon` pass ``validate(entries:horizon:)``.
	init(uncheckedEntries entries: [Entry], horizon: JulianDayNumber) {
		assert((try? Self.validate(entries: entries, horizon: horizon)) != nil, "Leap second table is invalid")
		self.entries = entries
		self.horizon = horizon
	}

	/// Built-in leap second table.
	public static let builtIn = LeapSecondTable(uncheckedEntries: taiUTCEntries, horizon: taiUTCHorizon)
}

extension LeapSecondTable {
	/// Returns the entry applicable to the specified Julian day number, or `nil` if none.
	func entryForUTCJulianDayNumber(_ J: JulianDayNumber) -> Entry? {
		var low = entries.startIndex
		var high = entries.endIndex
		while low != high {
			let distance = entries.distance(from: low, to: high)
			let mid = entries.index(low, offsetBy: distance / 2)
			if entries[mid].effective <= J {
				low = entries.index(after: mid)
			} else {
				high = mid
			}
		}
		return low == entries.startIndex ? nil : entries[low - 1]
	}
}

extension LeapSecondTable.Entry {
	/// TAI - UTC, in seconds, at the start of the UTC day `J`.
	func taiMinusUTC(atStartOfUTCDay J: JulianDayNumber) -> Double {
		offset + differenceAsDouble(J, reference) * rate
	}
}

// From https://maia.usno.navy.mil/ser7/tai-utc.dat
//
// `effective` and `reference` are civil-day Julian day numbers: the day that starts at the
// midnight JD in the source line, so `effective` = JD + 0.5 and `reference` = MJD + 2,400,001.
let taiUTCEntries: [LeapSecondTable.Entry] = [
	// 1961 JAN  1 =JD 2437300.5  TAI-UTC=   1.4228180 S + (MJD - 37300.) X 0.001296 S
	.init(effective: 2_437_301, offset: 1.4228180, reference: 2_437_301, rate: 0.001296),
	// 1961 AUG  1 =JD 2437512.5  TAI-UTC=   1.3728180 S + (MJD - 37300.) X 0.001296 S
	.init(effective: 2_437_513, offset: 1.3728180, reference: 2_437_301, rate: 0.001296),
	// 1962 JAN  1 =JD 2437665.5  TAI-UTC=   1.8458580 S + (MJD - 37665.) X 0.0011232S
	.init(effective: 2_437_666, offset: 1.8458580, reference: 2_437_666, rate: 0.0011232),
	// 1963 NOV  1 =JD 2438334.5  TAI-UTC=   1.9458580 S + (MJD - 37665.) X 0.0011232S
	.init(effective: 2_438_335, offset: 1.9458580, reference: 2_437_666, rate: 0.0011232),
	// 1964 JAN  1 =JD 2438395.5  TAI-UTC=   3.2401300 S + (MJD - 38761.) X 0.001296 S
	.init(effective: 2_438_396, offset: 3.2401300, reference: 2_438_762, rate: 0.001296),
	// 1964 APR  1 =JD 2438486.5  TAI-UTC=   3.3401300 S + (MJD - 38761.) X 0.001296 S
	.init(effective: 2_438_487, offset: 3.3401300, reference: 2_438_762, rate: 0.001296),
	// 1964 SEP  1 =JD 2438639.5  TAI-UTC=   3.4401300 S + (MJD - 38761.) X 0.001296 S
	.init(effective: 2_438_640, offset: 3.4401300, reference: 2_438_762, rate: 0.001296),
	// 1965 JAN  1 =JD 2438761.5  TAI-UTC=   3.5401300 S + (MJD - 38761.) X 0.001296 S
	.init(effective: 2_438_762, offset: 3.5401300, reference: 2_438_762, rate: 0.001296),
	// 1965 MAR  1 =JD 2438820.5  TAI-UTC=   3.6401300 S + (MJD - 38761.) X 0.001296 S
	.init(effective: 2_438_821, offset: 3.6401300, reference: 2_438_762, rate: 0.001296),
	// 1965 JUL  1 =JD 2438942.5  TAI-UTC=   3.7401300 S + (MJD - 38761.) X 0.001296 S
	.init(effective: 2_438_943, offset: 3.7401300, reference: 2_438_762, rate: 0.001296),
	// 1965 SEP  1 =JD 2439004.5  TAI-UTC=   3.8401300 S + (MJD - 38761.) X 0.001296 S
	.init(effective: 2_439_005, offset: 3.8401300, reference: 2_438_762, rate: 0.001296),
	// 1966 JAN  1 =JD 2439126.5  TAI-UTC=   4.3131700 S + (MJD - 39126.) X 0.002592 S
	.init(effective: 2_439_127, offset: 4.3131700, reference: 2_439_127, rate: 0.002592),
	// 1968 FEB  1 =JD 2439887.5  TAI-UTC=   4.2131700 S + (MJD - 39126.) X 0.002592 S
	.init(effective: 2_439_888, offset: 4.2131700, reference: 2_439_127, rate: 0.002592),
	// 1972 JAN  1 =JD 2441317.5  TAI-UTC=  10.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_441_318, offset: 10, reference: 2_441_318, rate: 0),
	// 1972 JUL  1 =JD 2441499.5  TAI-UTC=  11.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_441_500, offset: 11, reference: 2_441_318, rate: 0),
	// 1973 JAN  1 =JD 2441683.5  TAI-UTC=  12.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_441_684, offset: 12, reference: 2_441_318, rate: 0),
	// 1974 JAN  1 =JD 2442048.5  TAI-UTC=  13.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_442_049, offset: 13, reference: 2_441_318, rate: 0),
	// 1975 JAN  1 =JD 2442413.5  TAI-UTC=  14.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_442_414, offset: 14, reference: 2_441_318, rate: 0),
	// 1976 JAN  1 =JD 2442778.5  TAI-UTC=  15.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_442_779, offset: 15, reference: 2_441_318, rate: 0),
	// 1977 JAN  1 =JD 2443144.5  TAI-UTC=  16.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_443_145, offset: 16, reference: 2_441_318, rate: 0),
	// 1978 JAN  1 =JD 2443509.5  TAI-UTC=  17.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_443_510, offset: 17, reference: 2_441_318, rate: 0),
	// 1979 JAN  1 =JD 2443874.5  TAI-UTC=  18.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_443_875, offset: 18, reference: 2_441_318, rate: 0),
	// 1980 JAN  1 =JD 2444239.5  TAI-UTC=  19.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_444_240, offset: 19, reference: 2_441_318, rate: 0),
	// 1981 JUL  1 =JD 2444786.5  TAI-UTC=  20.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_444_787, offset: 20, reference: 2_441_318, rate: 0),
	// 1982 JUL  1 =JD 2445151.5  TAI-UTC=  21.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_445_152, offset: 21, reference: 2_441_318, rate: 0),
	// 1983 JUL  1 =JD 2445516.5  TAI-UTC=  22.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_445_517, offset: 22, reference: 2_441_318, rate: 0),
	// 1985 JUL  1 =JD 2446247.5  TAI-UTC=  23.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_446_248, offset: 23, reference: 2_441_318, rate: 0),
	// 1988 JAN  1 =JD 2447161.5  TAI-UTC=  24.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_447_162, offset: 24, reference: 2_441_318, rate: 0),
	// 1990 JAN  1 =JD 2447892.5  TAI-UTC=  25.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_447_893, offset: 25, reference: 2_441_318, rate: 0),
	// 1991 JAN  1 =JD 2448257.5  TAI-UTC=  26.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_448_258, offset: 26, reference: 2_441_318, rate: 0),
	// 1992 JUL  1 =JD 2448804.5  TAI-UTC=  27.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_448_805, offset: 27, reference: 2_441_318, rate: 0),
	// 1993 JUL  1 =JD 2449169.5  TAI-UTC=  28.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_449_170, offset: 28, reference: 2_441_318, rate: 0),
	// 1994 JUL  1 =JD 2449534.5  TAI-UTC=  29.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_449_535, offset: 29, reference: 2_441_318, rate: 0),
	// 1996 JAN  1 =JD 2450083.5  TAI-UTC=  30.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_450_084, offset: 30, reference: 2_441_318, rate: 0),
	// 1997 JUL  1 =JD 2450630.5  TAI-UTC=  31.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_450_631, offset: 31, reference: 2_441_318, rate: 0),
	// 1999 JAN  1 =JD 2451179.5  TAI-UTC=  32.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_451_180, offset: 32, reference: 2_441_318, rate: 0),
	// 2006 JAN  1 =JD 2453736.5  TAI-UTC=  33.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_453_737, offset: 33, reference: 2_441_318, rate: 0),
	// 2009 JAN  1 =JD 2454832.5  TAI-UTC=  34.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_454_833, offset: 34, reference: 2_441_318, rate: 0),
	// 2012 JUL  1 =JD 2456109.5  TAI-UTC=  35.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_456_110, offset: 35, reference: 2_441_318, rate: 0),
	// 2015 JUL  1 =JD 2457204.5  TAI-UTC=  36.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_457_205, offset: 36, reference: 2_441_318, rate: 0),
	// 2017 JAN  1 =JD 2457754.5  TAI-UTC=  37.0       S + (MJD - 41317.) X 0.0      S
	.init(effective: 2_457_755, offset: 37, reference: 2_441_318, rate: 0),
]

/// Julian day number of the first UTC day whose length is not yet determined by ``taiUTCEntries``.
///
/// Bulletin C 72 (2026-07-06) announced no leap second at the end of December 2026. The end of
/// June 2027 is undecided, so 2027-06-30 is the first day whose length is unknown.
let taiUTCHorizon: JulianDayNumber = 2_461_587 // 2027-06-30
