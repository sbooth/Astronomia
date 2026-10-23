//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// How many terms of the built-in series are summed, trading accuracy for speed.
///
/// The built-in planetary, lunar, and nutation series are sums of many periodic terms. Each
/// level keeps the terms large enough for its accuracy, is named for the bound on its error,
/// and leaves out the rest:
///
/// | Level | Largest error | Mars | Moon | Observation |
/// | --- | --- | --- | --- | --- |
/// | ``full`` | | 2.9 ms | 1.8 ms | 19 ms |
/// | ``tenMilliarcseconds`` | 6.0 mas | 1.3 ms | 1.2 ms | 12 ms |
/// | ``tenthArcsecond`` | 84 mas | 280 µs | 190 µs | 3.1 ms |
/// | ``arcsecond`` | 0.83" | 60 µs | 30 µs | 0.82 ms |
/// | ``tenArcseconds`` | 6.7" | 13 µs | 9 µs | 0.20 ms |
///
/// The error is the largest difference from the full series found over J1000.0 to J3000.0 in
/// the geocentric direction of the Moon or a planet other than Pluto, plus the largest angle by
/// which the truncated nutation turns the frames of date, which together bound a place in a
/// frame of date. It adds to the series' own error, which the full series' truncation, near
/// 0.5 mas, stays below. Pluto's series, less accurate to begin with, are truncated with the
/// planets' factors, for errors of up to 15 mas, 0.27", 2.4", and 31" at the coarser levels.
/// The times are for one evaluation of the series of Mars, the largest, and of the Moon, and for
/// an ``Observation``, which evaluates the Sun's barycentric state from every planet, in a
/// release build on Linux x86-64.
///
/// A coarser level evaluates the leading terms of the same data, so every level is always
/// available.
///
/// ```swift
/// let ephemeris = BuiltInEphemeris(precision: .arcsecond)
/// let earthOrientation = EarthOrientation(precision: .arcsecond)
/// ```
public enum Precision: Hashable, Sendable, CaseIterable {
	/// Every term of the built-in series.
	case full
	/// Within 10 milliarcseconds of the full series.
	case tenMilliarcseconds
	/// Within 0.1" of the full series.
	case tenthArcsecond
	/// Within 1" of the full series.
	case arcsecond
	/// Within 10" of the full series.
	case tenArcseconds
}

extension Precision {
	/// The level's index in the generated data, from 0 for ``full``.
	var level: Int {
		switch self {
		case .full: 0
		case .tenMilliarcseconds: 1
		case .tenthArcsecond: 2
		case .arcsecond: 3
		case .tenArcseconds: 4
		}
	}
}

/// Returns an element of the count or threshold tuple of the generated data at a level.
///
/// - Parameters:
///   - values: The values of the five levels.
///   - level: The level, from 0 to 4.
@inline(__always) func levelValue<T>(_ values: (T, T, T, T, T), _ level: Int) -> T {
	switch level {
	case 0: values.0
	case 1: values.1
	case 2: values.2
	case 3: values.3
	default: values.4
	}
}
