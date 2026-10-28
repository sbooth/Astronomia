//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import Testing
@testable import Astronomia

@Suite struct PCKFileTests {
	/// A PCK in the form of NAIF's, with comments, data across lines, and Fortran exponents.
	static let pck = """
		KPL/PCK

		Radii of some bodies, in km. The data below \\begindata isn't read until its own line.

		\\begindata

		BODY399_RADII     = ( 6378.1366   6378.1366   6356.7519 )
		BODY10_RADII      = ( 696000.  696000.  696000. )

		BODY2000004_RADII = ( 289.,
		                      280.,
		                      229. )
		BODY399_GM        = 3.98600435507D+05
		BODY599_RADII     = ( 71492 71492 66854 )

		\\begintext

		BODY499_RADII = ( 1 2 3 ) in a comment isn't read.

		\\begindata
		TARGET_NAMES     += ( 'ITOKAWA', 'O''BRIEN' )
		TARGET_NAMES     += 'RYUGU'
		LEAPSECOND        = @1972-JAN-1
		BODY599_RADII     = ( 71492 71492 66854 0 )
		BODY9_RADII       = ( 1188.3 1188.3 )
		BODY1_RADII       = ( 2440.53 2440.53 -1 )
		\\begintext
		"""

	@Test func variablesAreRead() throws {
		let pck = try PCKFile(text: Self.pck)
		#expect(pck.numbers(named: "BODY399_RADII") == [6378.1366, 6378.1366, 6356.7519])
		#expect(pck.numbers(named: "BODY2000004_RADII") == [289, 280, 229])
		#expect(pck.numbers(named: "BODY399_GM") == [398_600.435507])
		#expect(pck.numbers(named: "BODY499_RADII") == nil)
		#expect(pck.kernel.variables["TARGET_NAMES"] == [.string("ITOKAWA"), .string("O'BRIEN"), .string("RYUGU")])
		#expect(pck.kernel.variables["LEAPSECOND"] == [.date("1972-JAN-1")])
		#expect(pck.numbers(named: "TARGET_NAMES") == nil)
		// A later assignment replaces an earlier one.
		#expect(pck.numbers(named: "BODY599_RADII") == [71492, 71492, 66854, 0])
	}

	@Test func radiiAreTheLargerEquatorialAxes() throws {
		let pck = try PCKFile(text: Self.pck)
		#expect(pck.radius(of: 399) == .kilometers(6378.1366))
		#expect(pck.radius(of: 10) == .kilometers(696_000))
		#expect(pck.radius(of: 2_000_004) == .kilometers(289))
		// Not three radii, or not all positive, or not given
		#expect(pck.radius(of: 599) == nil)
		#expect(pck.radius(of: 9) == nil)
		#expect(pck.radius(of: 1) == nil)
		#expect(pck.radius(of: 499) == nil)
	}

	@Test func linesMayEndWithCarriageReturns() throws {
		let pck = try PCKFile(text: "\\begindata\r\nA = ( 1,\r\n 2 )\r\nB=3\r\n\\begintext\r\n")
		#expect(pck.numbers(named: "A") == [1, 2])
		#expect(pck.numbers(named: "B") == [3])
	}

	@Test func invalidDataGivesItsLine() {
		let cases: [(String, Int)] = [
			("\\begindata\nA = ( 1 2\n\\begintext\n", 2),
			("\\begindata\nA = 1\nB 2\n", 3),
			("\\begindata\nA = 1x\n", 2),
			("\\begindata\nA = 'open\n", 2),
			("\\begindata\nA = ( 1\n", 2),
			("\\begindata\n= 1\n", 2),
			("\\begindata\nA = nan\n", 2),
			// An assignment that doesn't end starts on the line of an assignment that does
			("\\begindata\nA = (\n1 ) B = (\n", 3),
			("\\begindata\nA = (\n1 ) B =\n\\begintext\n", 3),
		]
		for (text, line) in cases {
			#expect(throws: PCKError.invalidSyntax(line: line), "\(text)") { try PCKFile(text: text) }
		}
	}

	@Test func binaryKernelsAreRefused() {
		#expect(throws: PCKError.binaryKernel) { try PCKFile(contentsOf: SPKKernelTests.excerptPath) }
		#expect(throws: PCKError.binaryKernel) { try PCKFile(text: "DAF/PCK ") }
		#expect(throws: PCKError.binaryKernel) { try PCKFile(text: "NAIF/DAF") }
	}

	@Test func filesAreRead() throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("PCKFileTests-\(UUID().uuidString).tpc")
		try Self.pck.write(to: url, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: url) }
		#expect(try PCKFile(contentsOf: url.path) == PCKFile(text: Self.pck))
		#expect(throws: PCKError.cannotOpenFile(errno: ENOENT)) { try PCKFile(contentsOf: url.path + ".missing") }
	}

	@Test func bodiesTakeTheirRadii() throws {
		let pck = try PCKFile(text: Self.pck)
		let vesta = SPKEphemeris.Body(naifID: 2_000_004, radius: pck.radius(of: 2_000_004))
		#expect(vesta.radius == .kilometers(289))
		#expect(SPKEphemeris.Body(naifID: 2_000_004).radius == nil)
		// A body given its radius is still the ephemeris's body.
		let sun = SPKEphemeris.Body(naifID: 10, radius: pck.radius(of: 10))
		#expect(sun == SPKEphemeris.sun && sun.radius != SPKEphemeris.sun.radius)
		#expect(Set([sun, SPKEphemeris.sun]).count == 1)
	}
}
