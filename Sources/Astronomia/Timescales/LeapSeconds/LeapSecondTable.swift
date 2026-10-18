//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A table containing IERS Bulletin C leap second information.
///
/// Since 1972, TAI - UTC has been a whole number of seconds, changed only by leap seconds,
/// which the table holds with the expiry of the list they come from, the first UTC day it does
/// not cover. From 1961 through 1971, UTC followed UT with a rate offset and fractional steps.
/// That history does not change, so every table shares it.
///
/// ``builtIn`` is current as of the release of this library. For later leap seconds or a later
/// horizon, create a table from the IERS/IETF `leap-seconds.list` with
/// ``init(leapSecondsList:)`` or the IERS `Leap_Second.dat` with ``init(iersLeapSecondDat:)``.
///
/// - SeeAlso: [IERS Bulletin C](https://www.iers.org/iers/en/publications/bulletins/directlinks/bulletin-c-md)
public struct LeapSecondTable: Hashable, Sendable {
	/// TAI - UTC in whole seconds from the start of a UTC day.
	public struct LeapSecond: Hashable, Sendable {
		/// The Julian day number of the UTC day from whose start the offset applies.
		public let effective: JulianDayNumber
		/// TAI - UTC, in seconds.
		public let taiMinusUTC: Int

		/// Creates a leap second entry.
		///
		/// - Parameters:
		///   - effective: The Julian day number of the UTC day from whose start the offset
		///     applies.
		///   - taiMinusUTC: TAI - UTC, in seconds.
		public init(effective: JulianDayNumber, taiMinusUTC: Int) {
			self.effective = effective
			self.taiMinusUTC = taiMinusUTC
		}
	}

	/// TAI - UTC from 1972-01-01 on, in increasing order of effective day.
	public let leapSeconds: [LeapSecond]
	/// The Julian day number of the UTC day on which the published leap second list expires, the
	/// first it does not cover.
	public let horizon: JulianDayNumber

	/// Creates a leap second table.
	///
	/// - Parameters:
	///   - leapSeconds: TAI - UTC from 1972-01-01, when it was 10 s, in strictly increasing
	///     order of effective day. Each later entry is a leap second, so it differs from the
	///     one before by exactly one second, either way. Each must be in the right-open
	///     interval [0, 86,400) s, since converting TAI to UTC assumes UTC is behind TAI by
	///     less than a day.
	///   - horizon: The Julian day number of the UTC day on which the leap second list expires,
	///     the first it does not cover. Must be after the last leap second's effective day.
	/// - Returns: `nil` if `leapSeconds` does not begin at 1972-01-01 with 10 s, or the leap
	///   seconds or horizon are otherwise invalid.
	public init?(leapSeconds: [LeapSecond], horizon: JulianDayNumber) {
		guard let first = leapSeconds.first, first.effective == Self.firstDayOf1972, first.taiMinusUTC == 10,
			  let last = leapSeconds.last, horizon > last.effective
		else { return nil }

		for (index, leapSecond) in leapSeconds.enumerated() {
			guard leapSecond.taiMinusUTC >= 0, leapSecond.taiMinusUTC < Int(secondsPerDay) else { return nil }
			if index > 0 {
				let previous = leapSeconds[index - 1]
				guard leapSecond.effective > previous.effective,
					  (leapSecond.taiMinusUTC - previous.taiMinusUTC).magnitude == 1
				else { return nil }
			}
		}

		self.init(uncheckedLeapSeconds: leapSeconds, horizon: horizon)
	}

	/// Creates a leap second table from leap seconds already known to be valid.
	///
	/// - Precondition: `leapSeconds` and `horizon` satisfy the requirements of
	///   ``init(leapSeconds:horizon:)``.
	init(uncheckedLeapSeconds leapSeconds: [LeapSecond], horizon: JulianDayNumber) {
		self.leapSeconds = leapSeconds
		self.horizon = horizon
	}

	/// Built-in leap second table, from the IERS/IETF `leap-seconds.list`.
	public static let builtIn = LeapSecondTable(uncheckedLeapSeconds: builtInLeapSeconds, horizon: builtInLeapSecondsHorizon)
}

extension LeapSecondTable {
	/// The Julian day number of 1972-01-01, from which TAI - UTC is a whole number of seconds.
	static let firstDayOf1972: JulianDayNumber = 2_441_318

	/// Returns TAI - UTC at the start of a UTC day and its rate of change.
	///
	/// Before 1972 this comes from the fixed rate segments of `tai-utc.dat`, and from 1972 from
	/// the table's leap seconds, which are constant between leap seconds.
	///
	/// - Parameter J: The Julian day number of the UTC day.
	/// - Returns: TAI - UTC at the start of the day, in seconds, and its rate, in seconds per
	///   day, or `nil` before 1961-01-01.
	func taiMinusUTC(atStartOfUTCDay J: JulianDayNumber) -> (seconds: Double, rate: Double)? {
		guard J >= Self.firstDayOf1972 else {
			guard let segment = RateSegment.segment(forUTCJulianDayNumber: J) else { return nil }
			return (segment.taiMinusUTC(atStartOfUTCDay: J), segment.rate)
		}

		// The last leap second at or before `J`. The first is 1972-01-01, so there is one.
		var low = 0
		var high = leapSeconds.count - 1
		while low < high {
			let mid = (low + high + 1) / 2
			if leapSeconds[mid].effective <= J {
				low = mid
			} else {
				high = mid - 1
			}
		}
		return (Double(leapSeconds[low].taiMinusUTC), 0)
	}
}

extension LeapSecondTable {
	/// TAI - UTC from 1961 through 1971, when UTC followed UT with a rate offset.
	///
	/// TAI - UTC = offset + (day - reference) × rate from the start of the effective day.
	/// `effective` and `reference` are civil-day Julian day numbers: the day that starts at the
	/// midnight JD in each source line, so `effective` = JD + 0.5 and `reference` =
	/// MJD + 2,400,001.
	struct RateSegment: Hashable, Sendable {
		/// The Julian day number of the UTC day from whose start the segment applies.
		let effective: JulianDayNumber
		/// TAI - UTC at the start of the reference day, in seconds.
		let offset: Double
		/// The reference Julian day number.
		let reference: JulianDayNumber
		/// The rate of change of TAI - UTC, in seconds per day.
		let rate: Double

		/// TAI - UTC, in seconds, at the start of the UTC day `J`.
		func taiMinusUTC(atStartOfUTCDay J: JulianDayNumber) -> Double {
			offset + differenceAsDouble(J, reference) * rate
		}

		/// Returns the segment in effect on a UTC day before 1972, or `nil` before 1961.
		static func segment(forUTCJulianDayNumber J: JulianDayNumber) -> RateSegment? {
			all.last { $0.effective <= J }
		}

		/// The segments from https://maia.usno.navy.mil/ser7/tai-utc.dat, which do not change.
		static let all: [RateSegment] = [
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
		]
	}
}
