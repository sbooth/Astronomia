//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Instant where Scale == UTC {
	/// Returns the time elapsed from this instant to the specified instant, counting leap
	/// seconds.
	///
	/// UTC isn't a ``UniformTimescale``: a day ending in a leap second lasts 86,401 seconds, so
	/// the difference between two UTC Julian Dates spanning it is off by a second. This method
	/// measures the interval in ``TAI`` instead, so from 23:59:59 on December 31, 2016 to 00:00:01
	/// the next day, through the leap second 23:59:60, is 3 seconds, not 2. Before 1972, when the
	/// UTC second differed from the SI second, the interval is in SI seconds too.
	///
	/// The interval is positive if `other` is later than this instant.
	///
	/// ```swift
	/// let elapsed = try start.elapsed(to: .now)
	/// print(elapsed.inSeconds)
	/// ```
	///
	/// - Parameters:
	///   - other: The end of the interval.
	///   - context: The leap seconds and extrapolation policy for converting the instants to TAI.
	/// - Returns: `other` minus this instant, in days of 86,400 SI seconds.
	/// - Throws:
	///   - ``TimescaleConversionError/unsupported`` if either instant is before 1961, when UTC
	///     began.
	///   - ``TimescaleConversionError/leapSecondTableExpired`` if either instant is past the leap
	///     second table's horizon and `context` rejects extrapolation.
	///   - ``TimescaleConversionError/dateOutOfRange`` if either instant can't be converted to
	///     TAI, or the whole days in the interval can't be represented as an `Int`.
	public func elapsed(to other: Instant, context: UTC.Context = UTC.defaultContext) throws(TimescaleConversionError) -> DayInterval {
		let start = try converted(to: TAI.self, sourceContext: context)
		let end = try other.converted(to: TAI.self, sourceContext: context)
		do throws(DayIntervalError) {
			return try start.interval(to: end)
		} catch {
			throw TimescaleConversionError(error)
		}
	}
}
