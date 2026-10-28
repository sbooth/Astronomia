//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A text PCK, a SPICE planetary constants kernel, such as NAIF's pck00011.tpc, which gives the
/// radii of the planets, their satellites, and some asteroids and comets, or gm_de440.tpc,
/// which gives their gravitational parameters.
///
/// A PCK is a SPICE text kernel: it assigns values to variables between `\begindata` and
/// `\begintext` lines, and the rest of the file is comments.
///
/// ```
/// \begindata
/// BODY399_RADII = ( 6378.1366 6378.1366 6356.7519 )
/// BODY399_GM    = 3.98600435507D+05
/// \begintext
/// ```
///
/// Give a body of an ``SPKEphemeris`` its radius from a PCK:
///
/// ```swift
/// let pck = try PCKFile(contentsOf: "/path/to/pck00011.tpc")
/// let vesta = SPKEphemeris.Body(naifID: 2_000_004, radius: pck.radius(of: 2_000_004))
/// ```
///
/// Binary PCKs, of the orientation of the Earth and the Moon, aren't read.
///
/// See NAIF's PCK and Kernel Required Reading.
public struct PCKFile: Hashable, Sendable {
	/// The file's variables.
	let kernel: TextKernel

	/// Reads a text PCK.
	///
	/// - Parameter path: The file's path.
	/// - Throws: A ``PCKError``: ``PCKError/cannotOpenFile(errno:)`` if the file can't be
	///   opened, or another if it isn't a valid text PCK.
	public init(contentsOf path: String) throws(PCKError) {
		let data: KernelData
		do {
			data = try KernelData(mapping: path)
		} catch {
			guard case let .cannotOpenFile(errno) = error else { throw .cannotOpenFile(errno: 0) }
			throw .cannotOpenFile(errno: errno)
		}
		try self.init(text: String(decoding: data.bytes, as: UTF8.self))
	}

	/// Reads a text PCK from its text.
	///
	/// - Parameter text: The file's text.
	/// - Throws: ``PCKError/binaryKernel`` if the text is a binary kernel's, or
	///   ``PCKError/invalidSyntax(line:)`` if its data can't be read.
	public init(text: String) throws(PCKError) {
		// A DAF's identification word, as DAF/PCK, or the older NAIF/DAF
		guard !text.hasPrefix("DAF/"), !text.hasPrefix("NAIF/DAF") else { throw .binaryKernel }
		do {
			kernel = try TextKernel(text: text)
		} catch {
			throw .invalidSyntax(line: error.line)
		}
	}

	/// Returns the numbers of a variable.
	///
	/// - Parameter name: The variable's name, as `BODY399_RADII`.
	/// - Returns: The numbers, or `nil` if the file doesn't assign the variable or its values
	///   aren't all numbers; dates aren't converted to numbers, as SPICE converts them.
	public func numbers(named name: String) -> [Double]? {
		kernel.numbers(named: name)
	}

	/// Returns a body's equatorial radius, the larger of the two equatorial axes of its
	/// `BODYnnn_RADII`, which are in kilometers.
	///
	/// - Parameter naifID: The body's NAIF ID, as 399 for the Earth or 2,000,004 for Vesta.
	/// - Returns: The radius, or `nil` if the file doesn't give the body's three radii, each
	///   positive and finite.
	public func radius(of naifID: Int) -> Distance? {
		guard let radii = numbers(named: "BODY\(naifID)_RADII"), radii.count == 3, radii.allSatisfy({ $0.isFinite && $0 > 0 }) else {
			return nil
		}
		return .kilometers(max(radii[0], radii[1]))
	}
}
