//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaData

extension IAU2006 {
	/// A table of the IERS Conventions (2010), Chapter 5, from the built-in data: a polynomial
	/// part and series of terms t^j (S sin(ARG) + C cos(ARG)), where ARG is a sum of integer
	/// multiples of the fourteen fundamental arguments.
	struct SeriesData: @unchecked Sendable {
		// The data is immutable, so the pointers into it can be shared.
		/// The coefficients of t⁰ to t⁵ of the polynomial part, in microarcseconds.
		let polynomial: [Double]
		/// The series, each a power of time and number of terms at each precision level, with
		/// their terms in order of decreasing amplitude.
		let series: UnsafeBufferPointer<astronomia_iau_series>
		/// The terms, in the order of the series.
		let terms: UnsafeBufferPointer<astronomia_iau_term>
		/// The threshold of each precision level, below which terms are left out, in
		/// microarcseconds.
		let thresholds: (Double, Double, Double, Double, Double)
		/// The Julian epochs of the span the threshold applies to.
		let span: ClosedRange<Double>

		/// Creates a table from its generated data.
		init(_ data: astronomia_iau_series_data) {
			polynomial = withUnsafeBytes(of: data.polynomial) { Array($0.bindMemory(to: Double.self)) }
			series = UnsafeBufferPointer(start: data.series, count: data.series_count)
			terms = UnsafeBufferPointer(start: data.terms, count: data.term_count)
			thresholds = data.thresholds
			span = data.start_epoch ... data.end_epoch
		}
	}
}

extension IAU2006.SeriesData {
	/// The number of terms.
	var termCount: Int {
		terms.count
	}

	/// Returns the polynomial part at a time.
	///
	/// - Parameter t: TT in Julian centuries from J2000.0.
	/// - Returns: The value, in microarcseconds.
	func polynomialValue(at t: Double) -> Double {
		var value = 0.0
		for coefficient in polynomial.reversed() {
			value = value * t + coefficient
		}
		return value
	}

	/// Returns the sum of the series at a time.
	///
	/// The leading terms of the precision level are summed from the last, the smallest, to the
	/// first, so the small terms are not lost in the large ones.
	///
	/// - Parameters:
	///   - t: TT in Julian centuries from J2000.0.
	///   - arguments: The fourteen fundamental arguments at `t`, in radians.
	///   - precision: The precision level.
	/// - Returns: The sum, in microarcseconds.
	func seriesValue(at t: Double, arguments: IAU2006.FundamentalArguments, precision: Precision) -> Double {
		let a = arguments.values
		return withUnsafeBytes(of: a) { argumentBytes in
			guard
				let argumentPointer = argumentBytes.bindMemory(to: Double.self).baseAddress,
				let seriesPointer = series.baseAddress,
				let termsPointer = terms.baseAddress
			else { return 0 }
			return astronomia_iau_series_evaluate(seriesPointer, series.count, termsPointer, terms.count, argumentPointer, t, Int32(precision.level))
		}
	}

	/// Returns the polynomial part plus the series at a time.
	///
	/// - Parameters:
	///   - t: TT in Julian centuries from J2000.0.
	///   - arguments: The fourteen fundamental arguments at `t`, in radians.
	///   - precision: The precision level of the series.
	/// - Returns: The value, in microarcseconds.
	func value(at t: Double, arguments: IAU2006.FundamentalArguments, precision: Precision = .full) -> Double {
		polynomialValue(at: t) + seriesValue(at: t, arguments: arguments, precision: precision)
	}
}
