//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The data of an SPK segment of type 1 or 21: modified difference arrays, the records of JPL's
/// variable-step integrator, as of asteroids and comets from Horizons.
///
/// A record, or difference line, of a table of dimension D, of 4D + 11 words, is the record's
/// final epoch, the D step sizes, the reference position and velocity, by component (x, ẋ, y,
/// ẏ, z, ż), the modified divided differences of each component in turn, D words each, the
/// largest integration order plus 1, and the integration order of each component. The data is
/// the records, then the final epochs of the records in increasing order, a directory of every
/// hundredth epoch, then for type 21 the dimension, and the number of records. The dimension of
/// type 1 is 15.
///
/// See NAIF's SPK Required Reading.
struct SPKDifferenceLinesSegment: Hashable, Sendable {
	/// The address of the first record.
	let firstAddress: Int
	/// The number of records.
	let recordCount: Int
	/// The dimension of the difference tables.
	let dimension: Int
	/// The address of the records' final epochs.
	let epochsAddress: Int

	/// The size of a record, in words.
	var recordSize: Int {
		4 * dimension + 11
	}

	/// The dimension of the tables of type 1.
	static let type1Dimension = 15
	/// The largest dimension, past SPICE's limit of 25.
	static let largestDimension = 100

	/// Reads the directory of a segment's data.
	///
	/// - Parameters:
	///   - reader: The reader of the file's bytes.
	///   - addresses: The addresses of the segment's data.
	///   - type: The segment's type: 1 or 21.
	/// - Throws: ``SPKError/invalidFile`` if the directory doesn't describe the data.
	init(reader: KernelReader, addresses: ClosedRange<Int>, type: Int) throws(SPKError) {
		guard addresses.count >= 2 else { throw .invalidFile }
		let end = addresses.upperBound
		let count = reader.double(atAddress: end)
		guard count == count.rounded(), count >= 1, count <= Double(addresses.count) else { throw .invalidFile }
		let trailer: Int
		switch type {
		case 1:
			dimension = Self.type1Dimension
			trailer = 1
		case 21:
			let size = reader.double(atAddress: end - 1)
			guard size == size.rounded(), size >= 1, size <= Double(Self.largestDimension) else { throw .invalidFile }
			dimension = Int(size)
			trailer = 2
		default:
			throw .invalidFile
		}
		recordCount = Int(count)
		let recordSize = 4 * dimension + 11
		guard (recordSize + 1) * recordCount + recordCount / 100 + trailer == addresses.count else { throw .invalidFile }
		firstAddress = addresses.lowerBound
		epochsAddress = addresses.lowerBound + recordSize * recordCount
	}

	/// Returns the state at a time, in kilometers and kilometers per second.
	///
	/// The record is the first whose final epoch is at or after the time, or the last for a time
	/// after it. The evaluation is SPICE's SPKE21.
	///
	/// - Parameters:
	///   - seconds: TDB seconds from J2000.0.
	///   - reader: The reader of the file's bytes.
	/// - Returns: The position and velocity, not finite if the record is damaged.
	func state(at seconds: Double, reader: KernelReader) -> (position: Vector3, velocity: Vector3) {
		let index = min(reader.countOfDoubles(atAddress: epochsAddress, count: recordCount, before: seconds), recordCount - 1)
		let record = firstAddress + index * recordSize
		let d = dimension
		/// Returns the word of the record at a 0-based offset.
		func word(_ offset: Int) -> Double {
			reader.double(atAddress: record + offset)
		}
		let invalid = (Vector3(.nan, .nan, .nan), Vector3(.nan, .nan, .nan))

		// The orders, which index the tables
		let largestOrder = word(4 * d + 7)
		guard largestOrder == largestOrder.rounded(), largestOrder >= 1, largestOrder <= Double(d + 2) else { return invalid }
		let kqmax1 = Int(largestOrder)
		var orders = [0, 0, 0]
		for i in 0 ..< 3 {
			let order = word(4 * d + 8 + i)
			guard order == order.rounded(), order >= 0, order <= Double(min(kqmax1 - 1, d)) else { return invalid }
			orders[i] = Int(order)
		}

		// The Fortran's 1-based arrays, with an unused element 0
		let delta = seconds - word(0)
		var tp = delta
		let mq2 = kqmax1 - 2
		var fc = [Double](repeating: 0, count: max(mq2, 0) + 2)
		var wc = [Double](repeating: 0, count: max(mq2, 0) + 1)
		for j in stride(from: 1, through: mq2, by: 1) {
			let g = word(j)
			guard g != 0 else { return invalid }
			fc[j + 1] = tp / g
			wc[j] = delta / g
			tp = delta + g
		}
		var w = [Double](repeating: 0, count: kqmax1 + 1)
		for j in 1 ... kqmax1 {
			w[j] = 1 / Double(j)
		}
		var ks = kqmax1 - 1
		var ks1 = ks - 1
		var jx = 0
		while ks >= 2 {
			jx += 1
			for j in 1 ... jx {
				w[j + ks] = fc[j + 1] * w[j + ks1] - wc[j] * w[j + ks]
			}
			ks = ks1
			ks1 -= 1
		}

		/// Returns Σ DT(j, i) W(j + ks) over a component's table, from the highest order.
		func sum(_ component: Int) -> Double {
			var sum = 0.0
			for j in stride(from: orders[component], through: 1, by: -1) {
				sum += word(d + 7 + component * d + j - 1) * w[j + ks]
			}
			return sum
		}
		var position = [0.0, 0.0, 0.0]
		for i in 0 ..< 3 {
			position[i] = word(d + 1 + 2 * i) + delta * (word(d + 2 + 2 * i) + delta * sum(i))
		}
		for j in stride(from: 1, through: jx, by: 1) {
			w[j + ks] = fc[j + 1] * w[j + ks1] - wc[j] * w[j + ks]
		}
		ks -= 1
		var velocity = [0.0, 0.0, 0.0]
		for i in 0 ..< 3 {
			velocity[i] = word(d + 2 + 2 * i) + delta * sum(i)
		}
		return (Vector3(position[0], position[1], position[2]), Vector3(velocity[0], velocity[1], velocity[2]))
	}
}
