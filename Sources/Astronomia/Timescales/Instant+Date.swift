//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(FoundationEssentials) || canImport(Foundation)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

extension Instant where Scale == UTC {
	/// Creates an instant from a `Date`.
	///
	/// `Date` counts seconds since 2001-01-01T00:00:00 UTC as POSIX time does, as if every day
	/// had 86,400 seconds, so the count is split into its UTC day and the clock reading on that
	/// day, and the day's length from the built-in leap second table gives the fraction, as for
	/// ``now``. On a day ending in a leap second the fraction is the reading / 86,401, as
	/// ``UTC`` requires. `Date` has no label for a leap second itself.
	///
	/// The instant is in UTC: convert it to the timescale a computation needs, as
	/// `try Instant<UTC>(date).converted(to: TT.self)`.
	///
	/// - Parameter date: The date.
	/// - Throws:
	///   - ``TimescaleConversionError/nonFiniteValue`` if the time interval of `date` is NaN or
	///     infinite.
	///   - ``TimescaleConversionError/dateOutOfRange`` if the Julian day number of its day
	///     can't be represented.
	///   - ``TimescaleConversionError/unsupported`` if `date` is before January 1, 1961, when
	///     UTC began.
	public init(_ date: Date) throws(TimescaleConversionError) {
		let interval = date.timeIntervalSinceReferenceDate
		guard interval.isFinite else { throw .nonFiniteValue }
		// Split the interval without rounding away whole days or clock seconds.
		let split: (days: Int, fractionSinceMidnight: Double)
		do throws(DayAccumulator.Failure) {
			var accumulator = DayAccumulator(days: Self.referenceDateJulianDayNumber)
			try accumulator.add(seconds: interval)
			split = try accumulator.flooredResult()
		} catch {
			throw .dateOutOfRange
		}
		let julianDayNumber = split.days
		let seconds = split.fractionSinceMidnight * secondsPerDay
		let day = try UTCDay(julianDayNumber: julianDayNumber)
		self.init(try day.julianDate(secondsSinceMidnight: seconds))
	}

	/// The instant as a `Date`.
	///
	/// `Date` counts days of 86,400 seconds, so the clock reading on the instant's UTC day is
	/// added to the whole days since 2001-01-01. A `Date` has no label for a leap second:
	/// during 23:59:60 the result repeats 23:59:59, as most system clocks do.
	///
	/// - Note: The result is limited by the precision of the `Double` that `Date` stores,
	///   about 0.1 µs near the present.
	/// - Throws: ``TimescaleConversionError/unsupported`` if the instant is before
	///   January 1, 1961, when UTC began.
	public var date: Date {
		get throws(TimescaleConversionError) {
			let day = try UTCDay(containing: julianDate)
			var seconds = try day.secondsSinceMidnight(at: julianDate)
			// Past the 86,400 seconds of a day of `Date`, during a leap second or a pre-1972 step,
			// the reading repeats the end of the day.
			if seconds >= secondsPerDay {
				seconds -= day.clockSeconds - secondsPerDay
			}
			let days = differenceAsDouble(julianDate.julianDayNumber, Self.referenceDateJulianDayNumber)
			return Date(timeIntervalSinceReferenceDate: seconds.addingProduct(days, secondsPerDay))
		}
	}

	/// The Julian day number of 2001-01-01, the day of the `Date` reference epoch.
	static var referenceDateJulianDayNumber: JulianDayNumber {
		2_451_911
	}
}

#endif
