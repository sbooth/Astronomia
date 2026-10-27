//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The data of an SPK segment of type 8, 9, 12, or 13: discrete states, interpolated over a
/// window of the states nearest the time.
///
/// Types 8 and 9 interpolate each component of the position and of the velocity by a Lagrange
/// polynomial; types 12 and 13 interpolate each component of the position, with the velocity as
/// its derivative, by a Hermite polynomial, whose derivative is the velocity. The states of types
/// 8 and 12 are at equal steps of time, and those of types 9 and 13 at the epochs the segment
/// lists.
///
/// The data is the states, of six words each, the position then the velocity, and then for
/// types 8 and 12 the epoch of the first state, the step, the size of the window less 1, and
/// the number of states; for types 9 and 13 the epochs, a directory of every hundredth epoch,
/// the size of the window less 1, and the number of states. The size of the window less 1 is
/// the degree of the Lagrange polynomial for types 8 and 9.
///
/// See NAIF's SPK Required Reading.
struct SPKDiscreteStatesSegment: Hashable, Sendable {
	/// The epochs of the states.
	enum Epochs: Hashable, Sendable {
		/// Equal steps from the first epoch, in TDB seconds from J2000.0, by the step, in
		/// seconds.
		case equalSteps(first: Double, step: Double)
		/// The epochs listed in increasing order from an address.
		case listed(address: Int)
	}

	/// The address of the first state.
	let firstAddress: Int
	/// The number of states.
	let stateCount: Int
	/// The number of states interpolated, at most ``stateCount``.
	let windowSize: Int
	/// Whether the states are interpolated by Hermite polynomials, as in types 12 and 13,
	/// rather than Lagrange polynomials.
	let isHermite: Bool
	/// The epochs of the states.
	let epochs: Epochs

	/// The largest window, far past SPICE's own limits.
	static let largestWindow = 64

	/// Reads the directory of a segment's data.
	///
	/// - Parameters:
	///   - reader: The reader of the file's bytes.
	///   - addresses: The addresses of the segment's data.
	///   - type: The segment's type: 8, 9, 12, or 13.
	/// - Throws: ``SPKError/invalidFile`` if the directory doesn't describe the data.
	init(reader: KernelReader, addresses: ClosedRange<Int>, type: Int) throws(SPKError) {
		guard addresses.count >= 8 else { throw .invalidFile }
		let end = addresses.upperBound
		let window = reader.double(atAddress: end - 1)
		let count = reader.double(atAddress: end)
		guard window == window.rounded(), window >= 0, window < Double(Self.largestWindow),
			  count == count.rounded(), count >= 1, count <= Double(addresses.count) else {
			throw .invalidFile
		}
		let n = Int(count)
		switch type {
		case 8, 12:
			let first = reader.double(atAddress: end - 3)
			let step = reader.double(atAddress: end - 2)
			guard 6 * n + 4 == addresses.count, first.isFinite, step.isFinite, step > 0 else {
				throw .invalidFile
			}
			epochs = .equalSteps(first: first, step: step)
		case 9, 13:
			guard 7 * n + (n - 1) / 100 + 2 == addresses.count else { throw .invalidFile }
			epochs = .listed(address: addresses.lowerBound + 6 * n)
		default:
			throw .invalidFile
		}
		firstAddress = addresses.lowerBound
		stateCount = n
		windowSize = min(Int(window) + 1, n)
		isHermite = type == 12 || type == 13
	}

	/// Returns the epoch of a state, in TDB seconds from J2000.0.
	@inline(__always) func epoch(_ index: Int, reader: KernelReader) -> Double {
		switch epochs {
		case let .equalSteps(first, step): first + Double(index) * step
		case let .listed(address): reader.double(atAddress: address + index)
		}
	}

	/// Returns the index of the first state of the window for a time.
	///
	/// A window of an odd number of states is centered on the state nearest the time, or the
	/// later of two as near, and one of an even number has as many states at or before the
	/// time as after it; either is moved within the states at the ends, as SPICE chooses.
	func firstIndex(at seconds: Double, reader: KernelReader) -> Int {
		let n = stateCount
		let first: Int
		switch epochs {
		case let .equalSteps(start, step):
			let offset = (seconds - start) / step
			let clamped = offset.isNaN ? 0 : min(max(offset, 0), Double(n - 1))
			if windowSize % 2 == 1 {
				first = Int(clamped.rounded(.toNearestOrAwayFromZero)) - (windowSize - 1) / 2
			} else {
				first = Int(clamped.rounded(.down)) - windowSize / 2 + 1
			}
		case let .listed(address):
			// The last state at or before the time, or -1 for none
			let last = reader.countOfDoubles(atAddress: address, count: n, notAfter: seconds) - 1
			if windowSize % 2 == 1 {
				let nearest: Int
				if last < 0 {
					nearest = 0
				} else if last == n - 1 {
					nearest = n - 1
				} else {
					let before = seconds - reader.double(atAddress: address + last)
					let after = reader.double(atAddress: address + last + 1) - seconds
					// A time midway takes the later state, as at equal steps.
					nearest = before < after ? last : last + 1
				}
				first = nearest - (windowSize - 1) / 2
			} else {
				first = last - windowSize / 2 + 1
			}
		}
		return min(max(first, 0), n - windowSize)
	}

	/// Returns the state at a time, in kilometers and kilometers per second.
	///
	/// - Parameters:
	///   - seconds: TDB seconds from J2000.0.
	///   - reader: The reader of the file's bytes.
	/// - Returns: The position and velocity.
	func state(at seconds: Double, reader: KernelReader) -> (position: Vector3, velocity: Vector3) {
		let first = firstIndex(at: seconds, reader: reader)
		let w = windowSize
		// The epochs relative to the time, which keeps the differences exact
		var offsets = [Double](repeating: 0, count: w)
		for i in 0 ..< w {
			offsets[i] = epoch(first + i, reader: reader) - seconds
		}
		/// Returns a word of the i-th state of the window.
		func word(_ i: Int, _ component: Int) -> Double {
			reader.double(atAddress: firstAddress + 6 * (first + i) + component)
		}
		var state = [Double](repeating: 0, count: 6)
		if isHermite {
			for component in 0 ..< 3 {
				let (value, derivative) = Self.hermite(offsets: offsets, values: { word($0, component) }, derivatives: { word($0, component + 3) })
				state[component] = value
				state[component + 3] = derivative
			}
		} else {
			for component in 0 ..< 6 {
				state[component] = Self.lagrange(offsets: offsets, values: { word($0, component) })
			}
		}
		return (Vector3(state[0], state[1], state[2]), Vector3(state[3], state[4], state[5]))
	}

	/// Returns the value at 0 of the Lagrange polynomial through some points, by Neville's
	/// algorithm.
	///
	/// - Parameters:
	///   - offsets: The abscissas of the points, distinct.
	///   - values: The ordinate of each point, by index.
	/// - Returns: The polynomial's value at 0.
	static func lagrange(offsets: [Double], values: (Int) -> Double) -> Double {
		let n = offsets.count
		var p = (0 ..< n).map(values)
		for j in 1 ..< max(n, 1) {
			for i in 0 ..< n - j {
				let (a, b) = (offsets[i], offsets[i + j])
				p[i] = (a * p[i + 1] - b * p[i]) / (a - b)
			}
		}
		return p[0]
	}

	/// Returns the value and derivative at 0 of the Hermite polynomial through some points with
	/// the given derivatives, by its Newton form, the divided differences of the points each
	/// taken twice.
	///
	/// - Parameters:
	///   - offsets: The abscissas of the points, distinct.
	///   - values: The ordinate of each point, by index.
	///   - derivatives: The derivative at each point, by index.
	/// - Returns: The polynomial's value and derivative at 0.
	static func hermite(offsets: [Double], values: (Int) -> Double, derivatives: (Int) -> Double) -> (value: Double, derivative: Double) {
		let m = 2 * offsets.count
		/// Returns the k-th abscissa, each taken twice.
		@inline(__always) func z(_ k: Int) -> Double { offsets[k / 2] }
		var q = (0 ..< m).map { values($0 / 2) }
		for j in 1 ..< max(m, 1) {
			for k in stride(from: m - 1, through: j, by: -1) {
				if j == 1, k % 2 == 1 {
					q[k] = derivatives(k / 2)
				} else {
					q[k] = (q[k] - q[k - 1]) / (z(k) - z(k - j))
				}
			}
		}
		// Horner's scheme for the Newton form at 0, where each factor x − zₖ is −zₖ
		var value = q[m - 1]
		var derivative = 0.0
		for k in stride(from: m - 2, through: 0, by: -1) {
			derivative = derivative * -z(k) + value
			value = value * -z(k) + q[k]
		}
		return (value, derivative)
	}
}

extension KernelReader {
	/// Returns the number of doubles, of a sequence in increasing order, that don't exceed a
	/// value, by binary search.
	///
	/// - Parameters:
	///   - address: The address of the first double.
	///   - count: The number of doubles.
	///   - value: The value.
	/// - Returns: The number of doubles not greater than the value, 0 if it is NaN.
	func countOfDoubles(atAddress address: Int, count: Int, notAfter value: Double) -> Int {
		var (low, high) = (0, count)
		while low < high {
			let middle = (low + high) / 2
			if double(atAddress: address + middle) <= value {
				low = middle + 1
			} else {
				high = middle
			}
		}
		return low
	}

	/// Returns the number of doubles, of a sequence in increasing order, less than a value, by
	/// binary search.
	///
	/// - Parameters:
	///   - address: The address of the first double.
	///   - count: The number of doubles.
	///   - value: The value.
	/// - Returns: The number of doubles less than the value, 0 if it is NaN.
	func countOfDoubles(atAddress address: Int, count: Int, before value: Double) -> Int {
		var (low, high) = (0, count)
		while low < high {
			let middle = (low + high) / 2
			if double(atAddress: address + middle) < value {
				low = middle + 1
			} else {
				high = middle
			}
		}
		return low
	}
}
