//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import Testing
@testable import Astronomia

@Suite struct SPKKernelTests {
	/// The path of the DE421 excerpt.
	static var excerptPath: String {
		guard let url = Bundle.module.url(forResource: "De421Excerpt", withExtension: "bsp", subdirectory: "Fixtures") else {
			fatalError("Missing Fixtures/De421Excerpt.bsp")
		}
		return url.path
	}

	/// A segment of a synthetic SPK file.
	struct Segment {
		var target: Int32 = 10
		var center: Int32 = 0
		var type: Int32 = 2
		var start: Double
		var end: Double
		var words: [Double]
	}

	/// Returns a synthetic SPK file with one summary record, a name record, and the segments'
	/// words.
	static func spk(bigEndian: Bool = false, format: String? = nil, segments: [Segment]) -> [UInt8] {
		var bytes = [UInt8](repeating: 0, count: 3 * 1_024)
		func put(_ data: [UInt8], at offset: Int) {
			bytes.replaceSubrange(offset ..< offset + data.count, with: data)
		}
		func int32(_ value: Int32) -> [UInt8] {
			withUnsafeBytes(of: bigEndian ? value.bigEndian : value.littleEndian, Array.init)
		}
		func double(_ value: Double) -> [UInt8] {
			withUnsafeBytes(of: bigEndian ? value.bitPattern.bigEndian : value.bitPattern.littleEndian, Array.init)
		}
		put(Array("DAF/SPK ".utf8), at: 0)
		put(int32(2), at: 8)
		put(int32(6), at: 12)
		put(Array("Synthetic".utf8), at: 16)
		put(int32(2), at: 76)
		put(int32(2), at: 80)
		put(Array((format ?? (bigEndian ? "BIG-IEEE" : "LTL-IEEE")).utf8), at: 88)
		put(SPKKernel.ftpValidation, at: 699)
		put(double(0) + double(0) + double(Double(segments.count)), at: 1_024)
		put([UInt8](repeating: 0x20, count: 1_024), at: 2_048)
		var address = 3 * 128 + 1
		for (index, segment) in segments.enumerated() {
			let summary = 1_024 + 24 + index * 40
			let integers = [segment.target, segment.center, 1, segment.type, Int32(address), Int32(address + segment.words.count - 1)]
			put(double(segment.start) + double(segment.end) + integers.flatMap(int32), at: summary)
			bytes += segment.words.flatMap(double)
			address += segment.words.count
		}
		put(int32(Int32(address)), at: 84)
		return bytes
	}

	/// A type 2 segment of two records, over [-100, 100] and [100, 300] s, of three
	/// coefficients a component.
	static let twoRecords = Segment(start: -100, end: 300, words: [
		0, 100, 1, 2, 3, 4, 0, -1, 0.5, 0, 0,
		200, 100, 10, 0, 0, 20, 1, 0, 30, 0, 1,
		-100, 200, 11, 2,
	])

	@Test func readsTheExcerptMappedOrFromBytes() throws {
		let bytes = try [UInt8](Data(contentsOf: URL(fileURLWithPath: Self.excerptPath)))
		for data in [try KernelData(mapping: Self.excerptPath), KernelData(copying: bytes)] {
			let kernel = try SPKKernel(data: data)
			#expect(data.count == 17_328)
			#expect(!kernel.reader.isBigEndian)
			#expect(kernel.segments.map { $0.target } == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 301, 399, 199, 299, 499])
			#expect(kernel.segments.map { $0.center } == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 1, 2, 4])
			#expect(kernel.segments.allSatisfy { $0.frame == 1 && $0.type == 2 && $0.chebyshev != nil })
			#expect(kernel.segments.allSatisfy { $0.start == 820_497_600 && $0.end == 823_176_000 })
		}
	}

	@Test func statesMatchJplephem() throws {
		let kernel = try SPKKernel(data: KernelData(mapping: Self.excerptPath))
		#expect(jplephemSPKStates.count == 84)
		for row in jplephemSPKStates {
			let segment = try #require(kernel.segments.first { $0.target == row.target && $0.center == row.center })
			#expect(segment.covers(row.seconds))
			let (position, velocity) = kernel.state(of: segment, at: row.seconds)
			let p = [position.x, position.y, position.z]
			let v = [velocity.x, velocity.y, velocity.z]
			// Within a few units in the last place of the largest component
			let pScale = row.position.map(abs).max() ?? 0
			let vScale = row.velocity.map(abs).max() ?? 0
			for i in 0 ..< 3 {
				#expect(abs(p[i] - row.position[i]) <= 1e-14 * pScale, "\(row.target) at \(row.seconds)")
				#expect(abs(v[i] - row.velocity[i]) <= 1e-12 * vScale, "\(row.target) at \(row.seconds)")
			}
		}
	}

	@Test func typeTwoEvaluatesThePolynomialAndItsRate() throws {
		for bigEndian in [false, true] {
			let kernel = try SPKKernel(data: KernelData(copying: Self.spk(bigEndian: bigEndian, segments: [Self.twoRecords])))
			#expect(kernel.reader.isBigEndian == bigEndian)
			let segment = try #require(kernel.segments.first)
			let chebyshev = try #require(segment.chebyshev)
			#expect(chebyshev.recordCount == 2 && chebyshev.coefficientCount == 3 && !chebyshev.hasVelocity)
			// s = 0.5: T = 1, 0.5, -0.5, and T′ = 0, 1, 2
			let (position, velocity) = kernel.state(of: segment, at: 50)
			#expect(position == Vector3(0.5, 4.5, 0.5))
			#expect(velocity == Vector3(0.08, -0.02, 0))
			// The boundary between the records takes the second, s = -1; the last instant takes
			// the second too, s = 1.
			#expect(kernel.state(of: segment, at: 100).position == Vector3(10, 19, 31))
			#expect(kernel.state(of: segment, at: 300).position == Vector3(10, 21, 31))
			#expect(kernel.state(of: segment, at: 300).velocity == Vector3(0, 0.01, 0.04))
		}
	}

	@Test func typeThreeTakesTheRatesFromTheirOwnPolynomials() throws {
		let segment = Segment(type: 3, start: -100, end: 100, words: [0, 100, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, -100, 200, 14, 1])
		let kernel = try SPKKernel(data: KernelData(copying: Self.spk(segments: [segment])))
		let read = try #require(kernel.segments.first)
		#expect(read.chebyshev?.hasVelocity == true && read.chebyshev?.coefficientCount == 2)
		let (position, velocity) = kernel.state(of: read, at: 50)
		#expect(position == Vector3(2, 5, 8))
		#expect(velocity == Vector3(11, 14, 17))
	}

	@Test func otherTypesAreReadWithoutPolynomials() throws {
		let segment = Segment(type: 13, start: 0, end: 1, words: [1, 2, 3])
		let kernel = try SPKKernel(data: KernelData(copying: Self.spk(segments: [segment, Self.twoRecords])))
		#expect(kernel.segments.map { $0.type } == [13, 2])
		#expect(kernel.segments.first?.chebyshev == nil)
	}

	@Test func theByteOrderIsFoundWithoutTheFormatName() throws {
		for bigEndian in [false, true] {
			let bytes = Self.spk(bigEndian: bigEndian, format: "\0\0\0\0\0\0\0\0", segments: [Self.twoRecords])
			#expect(try SPKKernel(data: KernelData(copying: bytes)).reader.isBigEndian == bigEndian)
		}
	}

	@Test func filesThatCantBeOpenedThrow() throws {
		#expect(throws: SPKError.cannotOpenFile(errno: ENOENT)) {
			try KernelData(mapping: "/nonexistent/de440.bsp")
		}
		#expect(throws: SPKError.cannotOpenFile(errno: EISDIR)) {
			try KernelData(mapping: NSTemporaryDirectory())
		}
		// An empty file maps, but isn't an SPK file.
		let empty = NSTemporaryDirectory() + "astronomia-empty-\(UUID().uuidString).bsp"
		#expect(FileManager.default.createFile(atPath: empty, contents: Data()))
		defer { try? FileManager.default.removeItem(atPath: empty) }
		let data = try KernelData(mapping: empty)
		#expect(data.count == 0)
		#expect(throws: SPKError.invalidFile) { try SPKKernel(data: data) }
	}

	@Test func damagedFilesThrow() throws {
		let valid = Self.spk(segments: [Self.twoRecords])
		func kernel(_ bytes: [UInt8]) throws(SPKError) -> SPKKernel {
			try SPKKernel(data: KernelData(copying: bytes))
		}
		#expect(throws: SPKError.invalidFile) { try kernel([]) }
		#expect(throws: SPKError.invalidFile) { try kernel(Array(valid.prefix(1_000))) }
		var other = valid
		other.replaceSubrange(0 ..< 8, with: Array("DAF/PCK ".utf8))
		#expect(throws: SPKError.invalidFile) { try kernel(other) }
		// A VAX file
		#expect(throws: SPKError.unsupportedFormat) { try kernel(Self.spk(format: "VAX-GFLT", segments: [Self.twoRecords])) }
		// A transfer in text mode, which turns a line feed into a carriage return and line feed
		var transferred = valid
		transferred.replaceSubrange(708 ..< 709, with: [0x0D, 0x0A])
		transferred.removeLast()
		#expect(throws: SPKError.damagedInTransfer) { try kernel(transferred) }
		// Cut short, so a segment's data is missing
		#expect(throws: SPKError.invalidFile) { try kernel(Array(valid.dropLast(8))) }
		// A directory that doesn't describe the data
		var segment = Self.twoRecords
		segment.words[segment.words.count - 1] = 3
		#expect(throws: SPKError.invalidFile) { try kernel(Self.spk(segments: [segment])) }
		segment = Self.twoRecords
		segment.words[segment.words.count - 3] = 0
		#expect(throws: SPKError.invalidFile) { try kernel(Self.spk(segments: [segment])) }
		// An interval that ends before it starts
		segment = Self.twoRecords
		segment.end = -200
		#expect(throws: SPKError.invalidFile) { try kernel(Self.spk(segments: [segment])) }
		// A summary record that points to itself
		var looped = valid
		looped.replaceSubrange(1_024 ..< 1_032, with: withUnsafeBytes(of: Double(2).bitPattern.littleEndian, Array.init))
		#expect(throws: SPKError.invalidFile) { try kernel(looped) }
	}
}
