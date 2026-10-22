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
		/// The series, each a power of time and number of terms.
		let series: UnsafeBufferPointer<astronomia_iau_series>
		/// The terms, in the order of the series.
		let terms: UnsafeBufferPointer<astronomia_iau_term>
		/// The threshold below which terms were left out, in microarcseconds.
		let threshold: Double
		/// The Julian epochs of the span the threshold applies to.
		let span: ClosedRange<Double>

		/// Creates a table from its generated data.
		init(_ data: astronomia_iau_series_data) {
			polynomial = withUnsafeBytes(of: data.polynomial) { Array($0.bindMemory(to: Double.self)) }
			series = UnsafeBufferPointer(start: data.series, count: data.series_count)
			terms = UnsafeBufferPointer(start: data.terms, count: data.term_count)
			threshold = data.threshold
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
	/// The terms are summed from the last, the smallest, to the first, so the small terms are
	/// not lost in the large ones.
	///
	/// - Parameters:
	///   - t: TT in Julian centuries from J2000.0.
	///   - arguments: The fourteen fundamental arguments at `t`, in radians.
	/// - Returns: The sum, in microarcseconds.
	func seriesValue(at t: Double, arguments: IAU2006.FundamentalArguments) -> Double {
		let a = arguments.values
		var total = 0.0
		var end = terms.count
		for header in series.reversed() {
			let start = end - Int(header.count)
			var sum = 0.0
			for index in stride(from: end - 1, through: start, by: -1) {
				let term = terms[index]
				let m = term.multipliers
				// The sum of every multiple, most of them zero, is faster than testing for zeros.
				var argument = Double(m.0) * a.0 + Double(m.1) * a.1 + Double(m.2) * a.2 + Double(m.3) * a.3
				argument = argument + Double(m.4) * a.4 + Double(m.5) * a.5 + Double(m.6) * a.6 + Double(m.7) * a.7
				argument = argument + Double(m.8) * a.8 + Double(m.9) * a.9 + Double(m.10) * a.10 + Double(m.11) * a.11
				argument = argument + Double(m.12) * a.12 + Double(m.13) * a.13
				let (s, c) = Math.sincos(argument)
				sum = sum + (term.s * s + term.c * c)
			}
			var power = 1.0
			for _ in 0 ..< Int(header.power) {
				power = power * t
			}
			total = total + sum * power
			end = start
		}
		return total
	}

	/// Returns the polynomial part plus the series at a time.
	///
	/// - Parameters:
	///   - t: TT in Julian centuries from J2000.0.
	///   - arguments: The fourteen fundamental arguments at `t`, in radians.
	/// - Returns: The value, in microarcseconds.
	func value(at t: Double, arguments: IAU2006.FundamentalArguments) -> Double {
		polynomialValue(at: t) + seriesValue(at: t, arguments: arguments)
	}
}
