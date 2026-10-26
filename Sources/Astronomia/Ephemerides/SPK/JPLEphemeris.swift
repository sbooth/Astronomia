//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A planetary and lunar ephemeris of JPL's Development Ephemeris series, as DE440, DE441, or
/// DE421, from its SPK file.
///
/// JPL's ephemerides are numerical integrations fitted to observations of the planets, the
/// Moon, and spacecraft, and are the reference for the almanacs and JPL's Horizons system.
/// DE440 covers 1550 to 2650, DE441 about -13,200 to 17,191, in two files split at 1969, and
/// DE421 1900 to 2050. Download a file from https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/ and
/// give its path:
///
/// ```swift
/// let ephemeris = try JPLEphemeris(contentsOf: "/path/to/de440.bsp")
/// let place = try Observer.geocenter.apparentPlace(of: .mars, at: instant, ephemeris: ephemeris)
///
/// let de441 = try JPLEphemeris(files: [
/// 	SPKFile(contentsOf: "/path/to/de441_part-1.bsp"),
/// 	SPKFile(contentsOf: "/path/to/de441_part-2.bsp"),
/// ])
/// ```
///
/// A file is mapped into memory, so only the parts used are read. Every body of ``Body`` must
/// be in the files, relative to the solar system barycenter, as it is in each of JPL's
/// planetary ephemerides; their other segments, as Mars's center in DE421, are given by an
/// ``SPKEphemeris``. A state is the sum of the polynomials of the file's segments, without the
/// truncation of the ``BuiltInEphemeris``, so ``SeriesPrecision`` doesn't apply to it.
///
/// Light is deflected by the Sun, the Jupiter and Saturn systems, and the Earth, with the
/// gravitational parameters of DE440. States are converted from kilometers to astronomical
/// units of 149,597,870.7 km, and the file's J2000 frame is taken as the ICRS, as JPL's
/// ephemerides are aligned with the ICRF.
public struct JPLEphemeris: GeocentricEphemeris, Sendable {
	/// A body of the ephemeris.
	///
	/// Mars and the outer planets are the barycenters of their systems, as JPL's planetary
	/// ephemerides give them; Mercury and Venus, without satellites, are the planets.
	public enum Body: EphemerisBody, CaseIterable {
		/// The barycenter of the solar system.
		case solarSystemBarycenter
		/// The Sun.
		case sun
		/// Mercury.
		case mercury
		/// Venus.
		case venus
		/// The barycenter of the Earth and the Moon.
		case earthMoonBarycenter
		/// The Earth.
		case earth
		/// The Moon.
		case moon
		/// The barycenter of Mars and its satellites.
		case marsBarycenter
		/// The barycenter of Jupiter and its satellites.
		case jupiterBarycenter
		/// The barycenter of Saturn and its satellites.
		case saturnBarycenter
		/// The barycenter of Uranus and its satellites.
		case uranusBarycenter
		/// The barycenter of Neptune and its satellites.
		case neptuneBarycenter
		/// The barycenter of Pluto and its satellites.
		case plutoBarycenter

		/// The body's NAIF ID.
		public var naifID: Int? {
			id
		}

		/// The body's radius, as for the bodies of the ``BuiltInEphemeris``. The barycenters of
		/// the planets' systems take their planets' radii, and the solar system and Earth-Moon
		/// barycenters are points.
		public var radius: Distance? {
			NAIF.radius(of: id)
		}

		/// The body's NAIF ID.
		var id: Int {
			switch self {
			case .solarSystemBarycenter: 0
			case .sun: 10
			case .mercury: 199
			case .venus: 299
			case .earthMoonBarycenter: 3
			case .earth: 399
			case .moon: 301
			case .marsBarycenter: 4
			case .jupiterBarycenter: 5
			case .saturnBarycenter: 6
			case .uranusBarycenter: 7
			case .neptuneBarycenter: 8
			case .plutoBarycenter: 9
			}
		}
	}

	public typealias Frame = ICRS

	/// The solar system barycenter.
	public static let defaultOrigin = Body.solarSystemBarycenter
	public static let earth = Body.earth
	public static let sun = Body.sun
	public static let solarSystemBarycenter = Body.solarSystemBarycenter
	/// The Sun, the barycenters of Jupiter and Saturn, and the Earth, with their gravitational
	/// parameters from DE440 and their radii, as ``Body/radius`` gives them. The Earth deflects
	/// light only for an observer on its surface.
	public static let lightDeflectingBodies = [
		LightDeflectingBody(uncheckedBody: Body.sun, gravitationalParameter: DE440GravitationalParameters.sun),
		LightDeflectingBody(uncheckedBody: Body.jupiterBarycenter, gravitationalParameter: DE440GravitationalParameters.jupiterSystem),
		LightDeflectingBody(uncheckedBody: Body.saturnBarycenter, gravitationalParameter: DE440GravitationalParameters.saturnSystem),
		LightDeflectingBody(uncheckedBody: Body.earth, gravitationalParameter: DE440GravitationalParameters.earth),
	]

	/// The files, in increasing precedence.
	public let files: [SPKFile]
	/// The instants over which the files give every body.
	public let coverage: ClosedRange<Instant<TDB>>
	/// The segments of the file by target.
	let index: SPKSegmentIndex

	/// Creates an ephemeris from the SPK files of a planetary ephemeris.
	///
	/// - Parameter files: The files, in increasing precedence: where their segments overlap, a
	///   later file's are used.
	/// - Throws: ``SPKError/missingBody(naifID:)`` if the files don't give a body of ``Body``
	///   relative to the solar system barycenter, over a span common to all of them.
	public init(files: [SPKFile]) throws(SPKError) {
		let index = SPKSegmentIndex(files: files)
		var span = -Double.infinity ... Double.infinity
		for body in Body.allCases {
			guard let covered = index.coverage(of: body.id), covered.overlaps(span) else {
				throw .missingBody(naifID: body.id)
			}
			span = max(covered.lowerBound, span.lowerBound) ... min(covered.upperBound, span.upperBound)
		}
		guard let start = span.lowerBound.tdbInstant, let end = span.upperBound.tdbInstant else {
			throw .invalidFile
		}
		self.files = files
		self.index = index
		coverage = start ... end
	}

	/// Creates an ephemeris from a planetary ephemeris's SPK file.
	///
	/// - Parameter file: The file.
	/// - Throws: ``SPKError/missingBody(naifID:)`` if the file doesn't give a body of ``Body``
	///   relative to the solar system barycenter, over a span common to all of them.
	public init(file: SPKFile) throws(SPKError) {
		try self.init(files: [file])
	}

	/// Creates an ephemeris from a planetary ephemeris's SPK file, mapped into memory.
	///
	/// - Parameter path: The file's path.
	/// - Throws: An ``SPKError`` if the file can't be read, or doesn't give a body of ``Body``.
	public init(contentsOf path: String) throws(SPKError) {
		try self.init(file: SPKFile(contentsOf: path))
	}

	/// Creates an ephemeris from a planetary ephemeris's SPK file's bytes, which are copied.
	///
	/// - Parameter bytes: The file's bytes.
	/// - Throws: An ``SPKError`` if the bytes aren't an SPK file, or don't give a body of
	///   ``Body``.
	public init(bytes: some Collection<UInt8>) throws(SPKError) {
		try self.init(file: SPKFile(bytes: bytes))
	}

	/// Returns a body's state relative to another body.
	///
	/// - Parameters:
	///   - body: The body.
	///   - origin: The body to which the state is relative.
	///   - tdb: An instant in TDB.
	/// - Returns: The state, in the ICRS.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the instant is outside ``coverage``.
	///   - ``EphemerisError/invalidState`` if a segment gives a state that isn't finite.
	public func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
		guard coverage.contains(tdb) else { throw .outsideCoverage }
		return try index.stateVector(of: body.id, relativeTo: origin.id, at: tdb)
	}
}
