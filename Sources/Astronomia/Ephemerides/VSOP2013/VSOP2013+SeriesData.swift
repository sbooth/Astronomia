//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaData

extension VSOP2013 {
	/// A body's series from the built-in data, terms T^α (S sin(φ + ν T) + C cos(φ + ν T))
	/// grouped by variable and power of time.
	///
	/// The arguments are linear in time. Theories whose arguments are polynomials in time, such
	/// as the lunar theory ELP/MPP02, need their own form.
	///
	/// Each series has its terms in order of decreasing amplitude, and the number of leading
	/// terms at each precision level. The series of each variable are summed term by term in
	/// that order.
	struct SeriesData: @unchecked Sendable {
		// The data is immutable, so the pointers into it can be shared.
		/// The series, each a variable, power of time, and number of terms at each level.
		let series: UnsafeBufferPointer<astronomia_vsop_series>
		/// The terms, in the order of the series.
		let terms: UnsafeBufferPointer<astronomia_vsop_term>
		/// The largest power of time.
		let maximumPower: Int
		/// The Julian epochs of the span the series are truncated for.
		let span: ClosedRange<Double>
		/// The threshold of each precision level.
		let thresholds: (Double, Double, Double, Double, Double)

		/// Creates the series of a body from its generated data.
		init(_ data: astronomia_vsop_series_data) {
			series = UnsafeBufferPointer(start: data.series, count: data.series_count)
			terms = UnsafeBufferPointer(start: data.terms, count: data.term_count)
			maximumPower = series.reduce(0) { max($0, Int($1.power)) }
			span = data.start_epoch ... data.end_epoch
			thresholds = data.thresholds
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
	///   - precision: The precision level, whose leading terms of each series are summed.
	/// - Returns: The sums, indexed from 0.
	func evaluate(at t: Double, variables: Int, precision: Precision) -> [Double] {
		let level = precision.level
		var powers = [Double](repeating: 1, count: maximumPower + 1)
		if maximumPower > 0 {
			powers[1] = t
			for power in stride(from: 2, through: maximumPower, by: 1) {
				powers[power] = t * powers[power - 1]
			}
		}

		var sums = [Double](repeating: 0, count: variables)
		var start = 0
		for header in series {
			let variable = Int(header.variable) - 1
			let power = powers[Int(header.power)]
			var sum = sums[variable]
			let count = Int(levelValue(header.counts, level))
			if count > 0 {
				let seriesTerms = terms.baseAddress!.advanced(by: start)
				sum = astronomia_vsop_evaluate_series(seriesTerms, count, t, power, sum)
			}
			sums[variable] = sum
			start += Int(header.counts.0)
		}
		return sums
	}
}
