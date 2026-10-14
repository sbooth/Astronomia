//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Returns the interval from this Julian Date to the specified Julian Date.
	///
	/// The interval is positive if `other` is later than this Julian Date.
	///
	/// - Parameter other: The end of the interval.
	/// - Returns: `other` minus this Julian Date.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the interval
	///   cannot be represented as an `Int`.
	public func interval(to other: JulianDate) throws(DayIntervalError) -> DayInterval {
		try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(noonBased: other)
			try acc.subtract(noonBased: self)
		}
	}

	/// Returns the Julian Date advanced by the specified interval.
	///
	/// - Parameter interval: The interval to add.
	/// - Returns: This Julian Date plus `interval`.
	/// - Throws: ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///   number cannot be represented as a ``JulianDayNumber``.
	public func adding(_ interval: DayInterval) throws(JulianDateError) -> JulianDate {
		try JulianDate { acc throws(DayAccumulator.Failure) in
			try acc.add(noonBased: self)
			try acc.add(interval)
		}
	}

	/// Returns the Julian Date moved back by the specified interval.
	///
	/// - Parameter interval: The interval to subtract.
	/// - Returns: This Julian Date minus `interval`.
	/// - Throws: ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///   number cannot be represented as a ``JulianDayNumber``.
	public func subtracting(_ interval: DayInterval) throws(JulianDateError) -> JulianDate {
		try JulianDate { acc throws(DayAccumulator.Failure) in
			try acc.add(noonBased: self)
			try acc.subtract(interval)
		}
	}
}
