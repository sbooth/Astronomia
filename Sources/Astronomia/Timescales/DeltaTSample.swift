//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// ΔT at a TT date, as a sample of a table interpolated linearly in TT.
protocol DeltaTSample {
	/// The date, as a Julian Date in TT.
	var tt: JulianDate { get }
	/// ΔT = TT - UT1, in seconds.
	var deltaT: Double { get }
}

extension RandomAccessCollection where Element: DeltaTSample, Index == Int {
	/// Returns ΔT at the TT date whose UT1 is `ut1`, for ΔT interpolated linearly in TT between
	/// the samples, by inverse interpolation.
	///
	/// This is Meeus's inverse interpolation (*Astronomical Algorithms*, chapter 3) for a linear
	/// interpolant, which needs no iteration. A sample's UT1 is its TT minus its ΔT, computed as
	/// ``UT1/fromTT(_:context:)`` computes it. Between neighboring samples
	/// ΔT = ΔT_i + k (TT - TT_i), with k = (ΔT_i+1 - ΔT_i) / (TT_i+1 - TT_i), so
	/// UT1 - UT1_i = (1 - k)(TT - TT_i), and
	///
	///     ΔT = ΔT_i + (ΔT_i+1 - ΔT_i) (UT1 - UT1_i) / ((TT_i+1 - TT_i) - (ΔT_i+1 - ΔT_i)).
	///
	/// - Precondition: The samples' TT dates strictly increase, and ΔT changes between neighbors
	///   by less than the time between them, so their UT1 dates strictly increase too.
	/// - Parameter ut1: A Julian Date in UT1.
	/// - Returns: ΔT, in seconds, or `nil` if `ut1` is before the first sample's UT1 or after the
	///   last's. At a sample's UT1, the sample's ΔT.
	func inverseLinearDeltaT(atUT1 ut1: JulianDate) -> Double? {
		/// Returns the UT1 date of the sample at `index`.
		func ut1At(_ index: Int) -> JulianDate? {
			try? self[index].tt.adding(seconds: -self[index].deltaT)
		}

		guard !isEmpty, let firstUT1 = ut1At(startIndex), let lastUT1 = ut1At(endIndex - 1),
			  firstUT1 <= ut1, ut1 <= lastUT1
		else { return nil }

		// The last sample whose UT1 is at or before `ut1`.
		var low = startIndex
		var high = endIndex - 1
		while low < high {
			let mid = low + (high - low + 1) / 2
			guard let midUT1 = ut1At(mid) else { return nil }
			if midUT1 <= ut1 {
				low = mid
			} else {
				high = mid - 1
			}
		}

		// At a sample, return its value exactly.
		let a = self[low]
		guard let start = ut1At(low) else { return nil }
		guard low + 1 < endIndex, start < ut1 else { return a.deltaT }
		let b = self[low + 1]
		guard let elapsed = try? start.interval(to: ut1).inSeconds,
			  let span = try? a.tt.interval(to: b.tt).inSeconds
		else { return nil }
		let change = b.deltaT - a.deltaT
		return a.deltaT + change * (elapsed / (span - change))
	}
}
