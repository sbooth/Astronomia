//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An SPK file, the format of JPL's ephemerides: segments that each give one body's state
/// relative to another over an interval of time.
///
/// An SPK file is a DAF, NAIF's Double precision Array File: 1,024-byte records of 8-byte
/// words, addressed from 1. The first record names the format and the byte order and points to
/// a linked list of summary records, each holding the summaries of segments: the interval, in
/// TDB seconds from J2000.0, and the target, center, frame, type, and first and last address of
/// the segment's data. The states are in kilometers and kilometers per second. Types 2 and 3,
/// Chebyshev polynomials over equal intervals of time, as JPL's planetary ephemerides are
/// written; types 8, 9, 12, and 13, discrete states interpolated by Lagrange or Hermite
/// polynomials, as spacecraft are written; and types 1 and 21, modified difference arrays, as
/// JPL's small-body integrator writes asteroids and comets, are read, in the J2000 and
/// ECLIPJ2000 frames.
///
/// See NAIF's DAF and SPK Required Reading.
struct SPKKernel: Sendable {
	/// The reader of the file's bytes.
	let reader: KernelReader
	/// The segments, in the order of the file.
	let segments: [SPKSegment]

	/// The size of a DAF record, in bytes.
	static let recordSize = 1_024
	/// The DAF's FTP validation string, which a transfer in text mode changes.
	static let ftpValidation: [UInt8] = Array("FTPSTR:\r:\n:\r\n:\r\u{0}:".utf8) + [0x81, 0x3A, 0x10, 0xCE] + Array(":ENDFTP".utf8)

	/// Reads an SPK file's segments.
	///
	/// - Parameter data: The file's bytes.
	/// - Throws:
	///   - ``SPKError/invalidFile`` if the data isn't an SPK file or its structure is damaged.
	///   - ``SPKError/unsupportedFormat`` if its numbers aren't IEEE 754 binary.
	///   - ``SPKError/damagedInTransfer`` if its FTP validation string is damaged.
	init(data: KernelData) throws(SPKError) {
		let bytes = data.bytes
		guard bytes.count >= Self.recordSize else { throw .invalidFile }
		func string(_ offset: Int, _ count: Int) -> String {
			String(decoding: bytes[offset ..< offset + count], as: UTF8.self)
		}
		guard string(0, 8) == "DAF/SPK " else { throw .invalidFile }

		// The byte order, from the format's name, or else from the number of doubles and
		// integers of a summary, which an SPK file gives as 2 and 6
		let isBigEndian: Bool
		switch string(88, 8) {
		case "LTL-IEEE": isBigEndian = false
		case "BIG-IEEE": isBigEndian = true
		case let format where format.allSatisfy({ $0 == "\0" || $0 == " " }):
			let little = KernelReader(data: data, isBigEndian: false)
			let big = KernelReader(data: data, isBigEndian: true)
			if little.int32(atByte: 8) == 2, little.int32(atByte: 12) == 6 {
				isBigEndian = false
			} else if big.int32(atByte: 8) == 2, big.int32(atByte: 12) == 6 {
				isBigEndian = true
			} else {
				throw .invalidFile
			}
		default: throw .unsupportedFormat
		}
		let reader = KernelReader(data: data, isBigEndian: isBigEndian)
		guard reader.int32(atByte: 8) == 2, reader.int32(atByte: 12) == 6 else { throw .invalidFile }

		// Files older than the validation string have none.
		let ftp = Array(bytes[699 ..< 699 + Self.ftpValidation.count])
		if ftp.starts(with: Array("FTPSTR:".utf8)), ftp != Self.ftpValidation {
			throw .damagedInTransfer
		}

		// The linked list of summary records, each with the next record, the previous record,
		// and the number of summaries, then the summaries, of 2 doubles and 6 integers, five
		// words each
		let recordCount = bytes.count / Self.recordSize
		let wordCount = bytes.count / 8
		var segments: [SPKSegment] = []
		var record = Int(reader.int32(atByte: 76))
		var visited = Set<Int>()
		while record != 0 {
			guard record >= 2, record <= recordCount, visited.insert(record).inserted else { throw .invalidFile }
			let base = (record - 1) * Self.recordSize
			let next = reader.double(atByte: base)
			let count = reader.double(atByte: base + 16)
			guard next >= 0, next == next.rounded(), next <= Double(recordCount), count >= 0, count <= 25, count == count.rounded() else {
				throw .invalidFile
			}
			for index in 0 ..< Int(count) {
				let summary = base + 24 + index * 40
				let integers = (0 ..< 6).map { Int(reader.int32(atByte: summary + 16 + $0 * 4)) }
				let segment = try SPKSegment(
					reader: reader,
					start: reader.double(atByte: summary),
					end: reader.double(atByte: summary + 8),
					target: integers[0], center: integers[1], frame: integers[2], type: integers[3],
					addresses: integers[4] ... max(integers[4], integers[5]),
					wordCount: wordCount,
					isEmpty: integers[5] < integers[4])
				segments.append(segment)
			}
			record = Int(next)
		}
		self.reader = reader
		self.segments = segments
	}

	/// Returns a segment's state at a time, in kilometers and kilometers per second, in the
	/// J2000 frame.
	///
	/// - Parameters:
	///   - segment: The segment, one of ``segments``, that ``SPKSegment/isEvaluable``.
	///   - seconds: TDB seconds from J2000.0, within the segment's interval.
	/// - Returns: The position and velocity of the segment's target relative to its center, not
	///   finite if the segment's data is damaged.
	func state(of segment: SPKSegment, at seconds: Double) -> (position: Vector3, velocity: Vector3) {
		let state: (position: Vector3, velocity: Vector3)
		switch segment.data {
		case .chebyshev(let data): state = data.state(at: seconds, reader: reader)
		case .discreteStates(let data): state = data.state(at: seconds, reader: reader)
		case .differenceLines(let data): state = data.state(at: seconds, reader: reader)
		case nil: preconditionFailure("Segment of type \(segment.type) can't be evaluated")
		}
		switch segment.frame {
		case SPKSegment.j2000: return state
		case SPKSegment.eclipticJ2000: return (Self.fromEcliptic(state.position), Self.fromEcliptic(state.velocity))
		default: preconditionFailure("Segment in frame \(segment.frame) can't be evaluated")
		}
	}

	/// The cosine and sine of the obliquity of the ECLIPJ2000 frame, 84,381.448″, the IAU 1976
	/// value at J2000.0, as SPICE defines the frame.
	static let eclipticObliquity = (cos: Math.cos(84_381.448 / 3_600 * .pi / 180), sin: Math.sin(84_381.448 / 3_600 * .pi / 180))

	/// Rotates a vector from the ECLIPJ2000 frame to the J2000 frame, about the x-axis by the
	/// obliquity.
	static func fromEcliptic(_ v: Vector3) -> Vector3 {
		let (c, s) = eclipticObliquity
		return Vector3(v.x, c * v.y - s * v.z, s * v.y + c * v.z)
	}
}

/// A segment of an SPK file: one body's state relative to another over an interval of time.
struct SPKSegment: Hashable, Sendable {
	/// The NAIF ID of the body whose state the segment gives.
	let target: Int
	/// The NAIF ID of the body to which the state is relative.
	let center: Int
	/// The NAIF ID of the frame of the state, 1 for J2000, the ICRF for JPL's ephemerides, or
	/// 17 for ECLIPJ2000.
	let frame: Int
	/// The SPK data type.
	let type: Int
	/// The first instant the segment covers, in TDB seconds from J2000.0.
	let start: Double
	/// The last instant the segment covers, in TDB seconds from J2000.0.
	let end: Double
	/// The data's directory, or `nil` for a type that isn't read.
	let data: SPKSegmentData?

	/// The NAIF ID of the J2000 frame.
	static let j2000 = 1
	/// The NAIF ID of the ECLIPJ2000 frame, the mean ecliptic and equinox of J2000.0.
	static let eclipticJ2000 = 17

	/// Whether the segment's states can be evaluated: of a type that is read, in the J2000 or
	/// ECLIPJ2000 frame.
	var isEvaluable: Bool {
		data != nil && (frame == Self.j2000 || frame == Self.eclipticJ2000)
	}

	/// Reads a segment's summary and, for a type that is read, the directory of its data.
	///
	/// - Throws: ``SPKError/invalidFile`` if the summary or the data is damaged.
	init(reader: KernelReader, start: Double, end: Double, target: Int, center: Int, frame: Int, type: Int, addresses: ClosedRange<Int>, wordCount: Int, isEmpty: Bool) throws(SPKError) {
		guard start.isFinite, end.isFinite, start <= end, !isEmpty, addresses.lowerBound >= 1, addresses.upperBound <= wordCount else {
			throw .invalidFile
		}
		self.target = target
		self.center = center
		self.frame = frame
		self.type = type
		self.start = start
		self.end = end
		switch type {
		case 2, 3: data = try .chebyshev(SPKChebyshevSegment(reader: reader, addresses: addresses, hasVelocity: type == 3))
		case 8, 9, 12, 13: data = try .discreteStates(SPKDiscreteStatesSegment(reader: reader, addresses: addresses, type: type))
		case 1, 21: data = try .differenceLines(SPKDifferenceLinesSegment(reader: reader, addresses: addresses, type: type))
		default: data = nil
		}
	}

	/// Whether the segment covers an instant, in TDB seconds from J2000.0.
	func covers(_ seconds: Double) -> Bool {
		seconds >= start && seconds <= end
	}
}

/// The data of an SPK segment, by the family of its type.
enum SPKSegmentData: Hashable, Sendable {
	/// Chebyshev polynomials, types 2 and 3.
	case chebyshev(SPKChebyshevSegment)
	/// Discrete states, types 8, 9, 12, and 13.
	case discreteStates(SPKDiscreteStatesSegment)
	/// Modified difference arrays, types 1 and 21.
	case differenceLines(SPKDifferenceLinesSegment)
}

/// The data of an SPK segment of type 2 or 3: Chebyshev polynomials over equal intervals of
/// time.
///
/// The data is a sequence of records, then the directory: the first instant of the first
/// record, the length of each record's interval, in seconds, the size of a record, in words,
/// and the number of records. A record is the midpoint and half-length of its interval, then
/// the coefficients of each component in turn: x, y, and z, and for type 3, their rates.
struct SPKChebyshevSegment: Hashable, Sendable {
	/// The address of the first record.
	let firstAddress: Int
	/// The first instant of the first record, in TDB seconds from J2000.0.
	let initialEpoch: Double
	/// The length of each record's interval, in seconds.
	let intervalLength: Double
	/// The size of a record, in words.
	let recordSize: Int
	/// The number of records.
	let recordCount: Int
	/// The number of coefficients of each component.
	let coefficientCount: Int
	/// Whether the records have the coefficients of the velocity, as in type 3.
	let hasVelocity: Bool

	/// Reads the directory of a segment's data.
	///
	/// - Throws: ``SPKError/invalidFile`` if the directory doesn't describe the data.
	init(reader: KernelReader, addresses: ClosedRange<Int>, hasVelocity: Bool) throws(SPKError) {
		guard addresses.count >= 4 else { throw .invalidFile }
		let end = addresses.upperBound
		initialEpoch = reader.double(atAddress: end - 3)
		intervalLength = reader.double(atAddress: end - 2)
		let size = reader.double(atAddress: end - 1)
		let count = reader.double(atAddress: end)
		let components = hasVelocity ? 6 : 3
		guard initialEpoch.isFinite, intervalLength.isFinite, intervalLength > 0,
			  size == size.rounded(), size >= Double(2 + components), size <= 10_000,
			  count == count.rounded(), count >= 1, count <= Double(addresses.count) else {
			throw .invalidFile
		}
		recordSize = Int(size)
		recordCount = Int(count)
		guard (recordSize - 2) % components == 0, recordSize * recordCount + 4 == addresses.count else {
			throw .invalidFile
		}
		firstAddress = addresses.lowerBound
		coefficientCount = (recordSize - 2) / components
		self.hasVelocity = hasVelocity
	}

	/// Returns the state at a time, in kilometers and kilometers per second.
	///
	/// The record is the one whose interval holds the time, or the last for the end of the
	/// last interval; a time outside the records takes the nearest record's polynomials.
	///
	/// - Parameters:
	///   - seconds: TDB seconds from J2000.0.
	///   - reader: The reader of the file's bytes.
	/// - Returns: The position and velocity.
	func state(at seconds: Double, reader: KernelReader) -> (position: Vector3, velocity: Vector3) {
		let offset = ((seconds - initialEpoch) / intervalLength).rounded(.down)
		let index = offset.isNaN ? 0 : Int(min(max(offset, 0), Double(recordCount - 1)))
		let record = firstAddress + index * recordSize
		let midpoint = reader.double(atAddress: record)
		let radius = reader.double(atAddress: record + 1)
		let s = (seconds - midpoint) / radius
		/// Returns a component's value and rate.
		func component(_ index: Int) -> (value: Double, rate: Double) {
			let (value, derivative) = Self.evaluate(reader: reader, at: record + 2 + index * coefficientCount, count: coefficientCount, s: s)
			guard hasVelocity else { return (value, derivative / radius) }
			return (value, Self.evaluate(reader: reader, at: record + 2 + (index + 3) * coefficientCount, count: coefficientCount, s: s).value)
		}
		let (x, y, z) = (component(0), component(1), component(2))
		return (Vector3(x.value, y.value, z.value), Vector3(x.rate, y.rate, z.rate))
	}

	/// Returns a Chebyshev series and its derivative with respect to its argument.
	///
	/// With T₀ = 1, T₁ = s, and Tₖ = 2s Tₖ₋₁ − Tₖ₋₂, the series is Σ cₖ Tₖ(s), and its derivative
	/// Σ cₖ Tₖ′(s), with T₀′ = 0, T₁′ = 1, and Tₖ′ = 2Tₖ₋₁ + 2s Tₖ₋₁′ − Tₖ₋₂′.
	///
	/// - Parameters:
	///   - reader: The reader of the file's bytes.
	///   - address: The address of c₀.
	///   - count: The number of coefficients, at least 1.
	///   - s: The argument, in the closed interval [-1, 1] within the record's interval.
	/// - Returns: The series and its derivative.
	@inline(__always) static func evaluate(reader: KernelReader, at address: Int, count: Int, s: Double) -> (value: Double, derivative: Double) {
		var value = reader.double(atAddress: address)
		guard count > 1 else { return (value, 0) }
		let c1 = reader.double(atAddress: address + 1)
		value += c1 * s
		var derivative = c1
		var (t0, t1) = (1.0, s)
		var (d0, d1) = (0.0, 1.0)
		let twoS = 2 * s
		for k in 2 ..< count {
			let t2 = twoS * t1 - t0
			let d2 = 2 * t1 + twoS * d1 - d0
			let c = reader.double(atAddress: address + k)
			value += c * t2
			derivative += c * d2
			(t0, t1) = (t1, t2)
			(d0, d1) = (d1, d2)
		}
		return (value, derivative)
	}
}
