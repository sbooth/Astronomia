//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import AstronomiaData

extension VSOP2013 {
	/// Series of the VSOP planetary theories, terms T^α (S sin(φ + ν T) + C cos(φ + ν T)) grouped
	/// by variable and power of time, from the built-in data.
	///
	/// The arguments are linear in time. Theories whose arguments are polynomials in time, such
	/// as the lunar theory ELP/MPP02, need their own form.
	///
	/// The series of each variable are summed term by term in the order of the data, which is the
	/// order of the source files, as the reference implementations sum them.
	struct SeriesData: @unchecked Sendable {
		// The data is immutable, so the pointers into it can be shared.
		/// The series, each a variable, power of time, and number of terms.
		let series: UnsafeBufferPointer<astronomia_vsop_series>
		/// The terms, in the order of the series.
		let terms: UnsafeBufferPointer<astronomia_vsop_term>
		/// The largest power of time.
		let maximumPower: Int

		/// Creates series from generated data.
		init(_ data: astronomia_vsop_series_set) {
			series = UnsafeBufferPointer(start: data.series, count: data.series_count)
			terms = UnsafeBufferPointer(start: data.terms, count: data.term_count)
			maximumPower = series.reduce(0) { max($0, Int($1.power)) }
		}
	}
}

extension VSOP2013.SeriesData {
	/// The number of terms.
	var termCount: Int {
		terms.count
	}

	/// Returns the sum of each variable's series at a time.
	///
	/// - Parameters:
	///   - t: The time, in the unit of the series' frequencies.
	///   - variables: The number of variables, numbered from 1 in the data.
	/// - Returns: The sums, indexed from 0.
	func evaluate(at t: Double, variables: Int) -> [Double] {
		var powers = [Double](repeating: 1, count: maximumPower + 1)
		if maximumPower > 0 {
			powers[1] = t
			for power in stride(from: 2, through: maximumPower, by: 1) {
				powers[power] = t * powers[power - 1]
			}
		}

		var sums = [Double](repeating: 0, count: variables)
		var index = 0
		for series in series {
			let variable = Int(series.variable) - 1
			let power = powers[Int(series.power)]
			var sum = sums[variable]
			for _ in 0 ..< Int(series.count) {
				let term = terms[index]
				let (s, c) = Math.sincos(term.phase + term.frequency * t)
				sum = sum + power * (term.s * s + term.c * c)
				index += 1
			}
			sums[variable] = sum
		}
		return sums
	}
}
