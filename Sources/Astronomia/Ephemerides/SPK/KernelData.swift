//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaPlatform

/// The bytes of a kernel file, mapped into memory or copied there, read in the file's byte
/// order.
///
/// The bytes are never changed, and are freed or unmapped when the last reference to the data
/// goes away.
final class KernelData: @unchecked Sendable {
	/// How the bytes are held.
	private enum Storage {
		/// A mapping of a file.
		case mapped(astronomia_mapped_file)
		/// A copy, in memory allocated for it.
		case allocated
	}

	/// The bytes.
	let bytes: UnsafeRawBufferPointer
	/// How the bytes are held, for freeing them.
	private let storage: Storage

	/// Maps a file into memory.
	///
	/// - Parameter path: The file's path.
	/// - Throws: ``SPKError/cannotOpenFile(errno:)`` if the file can't be opened or mapped.
	init(mapping path: String) throws(SPKError) {
		var file = astronomia_mapped_file()
		let error = path.withCString { astronomia_map_file($0, &file) }
		guard error == 0 else {
			throw .cannotOpenFile(errno: error)
		}
		bytes = UnsafeRawBufferPointer(start: file.bytes, count: file.size)
		storage = .mapped(file)
	}

	/// Copies bytes into memory.
	///
	/// - Parameter source: The bytes.
	init(copying source: some Collection<UInt8>) {
		let copy = UnsafeMutableRawBufferPointer.allocate(byteCount: source.count, alignment: MemoryLayout<Double>.alignment)
		copy.copyBytes(from: source)
		bytes = UnsafeRawBufferPointer(copy)
		storage = .allocated
	}

	deinit {
		switch storage {
		case let .mapped(file): astronomia_unmap_file(file)
		case .allocated: bytes.deallocate()
		}
	}

	/// The number of bytes.
	var count: Int {
		bytes.count
	}
}

/// A reader of the numbers in a kernel's bytes, in the kernel's byte order.
///
/// The reader doesn't keep the bytes: whatever holds the reader must also hold the
/// ``KernelData``, as an ``SPKKernel`` does. So a reader is copied without reference counting.
///
/// The reads aren't checked: the offsets must be within the bytes.
struct KernelReader: @unchecked Sendable {
	/// The bytes, which are never changed.
	let bytes: UnsafeRawBufferPointer
	/// Whether the numbers are big-endian.
	let isBigEndian: Bool

	/// Creates a reader of a kernel's bytes.
	///
	/// - Parameters:
	///   - data: The bytes, which must be kept while the reader is used.
	///   - isBigEndian: Whether the numbers are big-endian.
	init(data: KernelData, isBigEndian: Bool) {
		bytes = data.bytes
		self.isBigEndian = isBigEndian
	}

	/// Returns the double at a byte offset.
	@inline(__always) func double(atByte offset: Int) -> Double {
		let raw = bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
		return Double(bitPattern: isBigEndian ? UInt64(bigEndian: raw) : UInt64(littleEndian: raw))
	}

	/// Returns the 32-bit integer at a byte offset.
	@inline(__always) func int32(atByte offset: Int) -> Int32 {
		let raw = bytes.loadUnaligned(fromByteOffset: offset, as: Int32.self)
		return isBigEndian ? Int32(bigEndian: raw) : Int32(littleEndian: raw)
	}

	/// Returns the double at a DAF address, a 1-based index of 8-byte words.
	@inline(__always) func double(atAddress address: Int) -> Double {
		double(atByte: (address - 1) * 8)
	}
}
