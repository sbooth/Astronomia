//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension DeltaTModel {
	/// A cubic in t = (y - start) / (end - start), for decimal years y from start to end.
	struct SplineInterval {
		let start: Double
		let end: Double
		/// The coefficients of 1, t, t², and t³.
		let a0, a1, a2, a3: Double

		func evaluate(_ y: Double) -> Double {
			let t = (y - start) / (end - start)
			return a0 + t * (a1 + t * (a2 + t * a3))
		}
	}

	/// The long-term parabola of Morrison et al. (2021), equation (5.1), in seconds.
	static func stephensonMorrisonHohenkerkParabola(_ y: Double) -> Double {
		let u = (y - 1825) / 100
		return -10 + 31.4 * u * u
	}

	/// ΔT from the spline of Stephenson, Morrison & Hohenkerk (2016), as revised by Morrison et
	/// al. (2021), with the long-term parabola outside it.
	///
	/// - Parameter y: The decimal year.
	static func stephensonMorrisonHohenkerk2016(_ y: Double) -> Double {
		let intervals = stephensonMorrisonHohenkerkSpline
		let first = intervals[0]
		let last = intervals[intervals.count - 1]
		if y < first.start {
			return stephensonMorrisonHohenkerkParabola(y)
		}
		if y >= last.end {
			// The parabola's trend, offset to continue the spline
			let end = last.evaluate(last.end)
			return end + (stephensonMorrisonHohenkerkParabola(y) - stephensonMorrisonHohenkerkParabola(last.end))
		}

		// The last interval starting at or before `y`
		var low = 0
		var high = intervals.count - 1
		while low < high {
			let mid = (low + high + 1) / 2
			if intervals[mid].start <= y {
				low = mid
			} else {
				high = mid - 1
			}
		}
		return intervals[low].evaluate(y)
	}

	/// Table S5 of the electronic supplementary material to Morrison et al. (2021): the spline
	/// fitted to ΔT from -720.0 to 2019.0 (2020 August), as the years K(i) and K(i+1) bounding
	/// each row and the coefficients a0 to a3, in seconds. HM Nautical Almanac Office
	/// distributes the same table as Table S15.2020.
	static let stephensonMorrisonHohenkerkSpline: [SplineInterval] = [
		.init(start: -720, end: -100, a0: 20371.848, a1: -9999.586, a2:  776.247, a3:  409.160),
		.init(start: -100, end:  400, a0: 11557.668, a1: -5822.270, a2: 1303.151, a3: -503.433),
		.init(start:  400, end: 1000, a0:  6535.116, a1: -5671.519, a2: -298.291, a3: 1085.087),
		.init(start: 1000, end: 1150, a0:  1650.393, a1:  -753.210, a2:  184.811, a3:  -25.346),
		.init(start: 1150, end: 1300, a0:  1056.647, a1:  -459.628, a2:  108.771, a3:  -24.641),
		.init(start: 1300, end: 1500, a0:   681.149, a1:  -421.345, a2:   61.953, a3:  -29.414),
		.init(start: 1500, end: 1600, a0:   292.343, a1:  -192.841, a2:   -6.572, a3:   16.197),
		.init(start: 1600, end: 1650, a0:   109.127, a1:   -78.697, a2:   10.505, a3:    3.018),
		.init(start: 1650, end: 1720, a0:    43.952, a1:   -68.089, a2:   38.333, a3:   -2.127),
		.init(start: 1720, end: 1800, a0:    12.068, a1:     2.507, a2:   41.731, a3:  -37.939),
		.init(start: 1800, end: 1810, a0:    18.367, a1:    -3.481, a2:   -1.126, a3:    1.918),
		.init(start: 1810, end: 1820, a0:    15.678, a1:     0.021, a2:    4.629, a3:   -3.812),
		.init(start: 1820, end: 1830, a0:    16.516, a1:    -2.157, a2:   -6.806, a3:    3.250),
		.init(start: 1830, end: 1840, a0:    10.804, a1:    -6.018, a2:    2.944, a3:   -0.096),
		.init(start: 1840, end: 1850, a0:     7.634, a1:    -0.416, a2:    2.658, a3:   -0.539),
		.init(start: 1850, end: 1855, a0:     9.338, a1:     1.642, a2:    0.261, a3:   -0.883),
		.init(start: 1855, end: 1860, a0:    10.357, a1:    -0.486, a2:   -2.389, a3:    1.558),
		.init(start: 1860, end: 1865, a0:     9.040, a1:    -0.591, a2:    2.284, a3:   -2.477),
		.init(start: 1865, end: 1870, a0:     8.255, a1:    -3.456, a2:   -5.148, a3:    2.720),
		.init(start: 1870, end: 1875, a0:     2.371, a1:    -5.593, a2:    3.011, a3:   -0.914),
		.init(start: 1875, end: 1880, a0:    -1.126, a1:    -2.314, a2:    0.269, a3:   -0.039),
		.init(start: 1880, end: 1885, a0:    -3.210, a1:    -1.893, a2:    0.152, a3:    0.563),
		.init(start: 1885, end: 1890, a0:    -4.388, a1:     0.101, a2:    1.842, a3:   -1.438),
		.init(start: 1890, end: 1895, a0:    -3.884, a1:    -0.531, a2:   -2.474, a3:    1.871),
		.init(start: 1895, end: 1900, a0:    -5.017, a1:     0.134, a2:    3.138, a3:   -0.232),
		.init(start: 1900, end: 1905, a0:    -1.977, a1:     5.715, a2:    2.443, a3:   -1.257),
		.init(start: 1905, end: 1910, a0:     4.923, a1:     6.828, a2:   -1.329, a3:    0.720),
		.init(start: 1910, end: 1915, a0:    11.142, a1:     6.330, a2:    0.831, a3:   -0.825),
		.init(start: 1915, end: 1920, a0:    17.479, a1:     5.518, a2:   -1.643, a3:    0.262),
		.init(start: 1920, end: 1925, a0:    21.617, a1:     3.020, a2:   -0.856, a3:    0.008),
		.init(start: 1925, end: 1930, a0:    23.789, a1:     1.333, a2:   -0.831, a3:    0.127),
		.init(start: 1930, end: 1935, a0:    24.418, a1:     0.052, a2:   -0.449, a3:    0.142),
		.init(start: 1935, end: 1940, a0:    24.164, a1:    -0.419, a2:   -0.022, a3:    0.702),
		.init(start: 1940, end: 1945, a0:    24.426, a1:     1.645, a2:    2.086, a3:   -1.106),
		.init(start: 1945, end: 1950, a0:    27.050, a1:     2.499, a2:   -1.232, a3:    0.614),
		.init(start: 1950, end: 1953, a0:    28.932, a1:     1.127, a2:    0.220, a3:   -0.277),
		.init(start: 1953, end: 1956, a0:    30.002, a1:     0.737, a2:   -0.610, a3:    0.631),
		.init(start: 1956, end: 1959, a0:    30.760, a1:     1.409, a2:    1.282, a3:   -0.799),
		.init(start: 1959, end: 1962, a0:    32.652, a1:     1.577, a2:   -1.115, a3:    0.507),
		.init(start: 1962, end: 1965, a0:    33.621, a1:     0.868, a2:    0.406, a3:    0.199),
		.init(start: 1965, end: 1968, a0:    35.093, a1:     2.275, a2:    1.002, a3:   -0.414),
		.init(start: 1968, end: 1971, a0:    37.956, a1:     3.035, a2:   -0.242, a3:    0.202),
		.init(start: 1971, end: 1974, a0:    40.951, a1:     3.157, a2:    0.364, a3:   -0.229),
		.init(start: 1974, end: 1977, a0:    44.244, a1:     3.199, a2:   -0.323, a3:    0.172),
		.init(start: 1977, end: 1980, a0:    47.291, a1:     3.069, a2:    0.193, a3:   -0.192),
		.init(start: 1980, end: 1983, a0:    50.361, a1:     2.878, a2:   -0.384, a3:    0.081),
		.init(start: 1983, end: 1986, a0:    52.936, a1:     2.354, a2:   -0.140, a3:   -0.165),
		.init(start: 1986, end: 1989, a0:    54.984, a1:     1.577, a2:   -0.637, a3:    0.448),
		.init(start: 1989, end: 1992, a0:    56.373, a1:     1.648, a2:    0.708, a3:   -0.276),
		.init(start: 1992, end: 1995, a0:    58.453, a1:     2.235, a2:   -0.121, a3:    0.110),
		.init(start: 1995, end: 1998, a0:    60.678, a1:     2.324, a2:    0.210, a3:   -0.313),
		.init(start: 1998, end: 2001, a0:    62.898, a1:     1.804, a2:   -0.729, a3:    0.109),
		.init(start: 2001, end: 2004, a0:    64.083, a1:     0.674, a2:   -0.402, a3:    0.199),
		.init(start: 2004, end: 2007, a0:    64.553, a1:     0.466, a2:    0.194, a3:   -0.017),
		.init(start: 2007, end: 2010, a0:    65.197, a1:     0.804, a2:    0.144, a3:   -0.084),
		.init(start: 2010, end: 2013, a0:    66.061, a1:     0.839, a2:   -0.109, a3:    0.128),
		.init(start: 2013, end: 2016, a0:    66.920, a1:     1.007, a2:    0.277, a3:   -0.095),
		.init(start: 2016, end: 2019, a0:    68.109, a1:     1.277, a2:   -0.007, a3:   -0.139),
	]
}
