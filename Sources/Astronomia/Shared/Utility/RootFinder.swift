//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Finds the instants of events from samples on either side of them.
enum RootFinder {
	/// Finds where a function of a sample changes sign between two samples, by the Illinois
	/// method, safeguarded by bisection.
	///
	/// The bracket around the root narrows until it is within the tolerance. The Illinois
	/// method narrows it quickly where the function is nearly linear; where it is not, as for an
	/// altitude near transit, where the altitude barely changes, a step that fails to halve the
	/// bracket over two steps is followed by a bisection, so the bracket always closes: within
	/// about three times as many steps as bisection alone would take.
	///
	/// - Parameters:
	///   - a: The earlier sample.
	///   - b: The later sample, on the other side of the root.
	///   - time: Returns a sample's time.
	///   - tolerance: The width of the final bracket, in the unit of the times.
	///   - maximumIterations: The most samples to evaluate.
	///   - evaluate: Returns the sample at a time.
	///   - function: The function, negative on one side of the root and nonnegative on the
	///     other.
	/// - Returns: The end of the final bracket, within the tolerance of the root, with the
	///   smaller value of the function.
	static func refine<Sample, Failure: Error>(_ a: Sample, _ b: Sample, time: (Sample) -> Double, tolerance: Double, maximumIterations: Int, evaluate: (Double) throws(Failure) -> Sample, function: (Sample) -> Double) throws(Failure) -> Sample {
		var (lower, upper) = (a, b)
		var (fLower, fUpper) = (function(a), function(b))
		// The Illinois method halves the value kept at an end that a step doesn't move.
		var (weightedLower, weightedUpper) = (fLower, fUpper)
		var side = 0
		var widths = [time(upper) - time(lower)]
		for _ in 0 ..< maximumIterations {
			let (lowerTime, upperTime) = (time(lower), time(upper))
			let width = upperTime - lowerTime
			guard width > tolerance, fLower != 0, fUpper != 0 else { break }
			var next: Double
			if widths.count >= 3, width > widths[widths.count - 3] / 2 {
				next = (lowerTime + upperTime) / 2
			} else {
				next = (lowerTime * weightedUpper - upperTime * weightedLower) / (weightedUpper - weightedLower)
				if !(next > lowerTime && next < upperTime) {
					next = (lowerTime + upperTime) / 2
				}
			}
			let sample = try evaluate(next)
			let f = function(sample)
			if (f < 0) == (fUpper < 0) {
				upper = sample
				fUpper = f
				weightedUpper = f
				if side == -1 {
					weightedLower /= 2
				}
				side = -1
			} else {
				lower = sample
				fLower = f
				weightedLower = f
				if side == 1 {
					weightedUpper /= 2
				}
				side = 1
			}
			widths.append(time(upper) - time(lower))
		}
		return abs(fLower) <= abs(fUpper) ? lower : upper
	}
}
