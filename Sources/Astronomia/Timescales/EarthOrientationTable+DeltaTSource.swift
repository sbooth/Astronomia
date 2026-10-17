//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension EarthOrientationTable: DeltaTSource {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT, interpolated linearly between
	/// entries, or `nil` if `tt` is outside ``coverage``. Predicted entries are used.
	public func deltaT(at tt: JulianDate) -> Double? {
		deltaTAndPredictionStatus(at: tt)?.seconds
	}

	/// Returns ΔT at the TT date whose UT1 is the specified date, by inverse linear
	/// interpolation between entries. Predicted entries are used.
	///
	/// Entries are at least a day apart, and ΔT changes between neighbors by less than two
	/// seconds plus the leap seconds between them, at most one a day, so ΔT always changes
	/// more slowly than TT.
	///
	/// - Parameter ut1: A Julian Date in UT1.
	/// - Returns: ΔT, in seconds, or `nil` if the TT of `ut1` is outside ``coverage``. At the UT1
	///   of an entry, the entry's value.
	public func deltaT(atUT1 ut1: JulianDate) -> Double? {
		samples.inverseLinearDeltaT(atUT1: ut1)
	}
}

extension EarthOrientationTable.Sample: DeltaTSample {}
