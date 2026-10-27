//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An ephemeris from SPK files, of any bodies they give, by their NAIF IDs.
///
/// The files are searched as SPICE searches them: a later file takes precedence over an
/// earlier one where their segments overlap, and a later segment in a file over an earlier
/// one. So a planetary ephemeris can be joined by files of asteroids, comets, satellites, or
/// spacecraft, whose segments are relative to bodies of the planetary ephemeris:
///
/// ```swift
/// let ephemeris = try SPKEphemeris(files: [
/// 	SPKFile(contentsOf: "/path/to/de440.bsp"),
/// 	SPKFile(contentsOf: "/path/to/2000001.bsp"),
/// ])
/// let ceres = SPKEphemeris.Body(naifID: 2_000_001)
/// let place = try Observer.geocenter.apparentPlace(of: ceres, at: instant, ephemeris: ephemeris)
/// ```
///
/// The files must give the Earth, the Sun, and the barycenters of the Jupiter and Saturn
/// systems relative to the solar system barycenter, as a planetary ephemeris does, for the
/// places of bodies seen from the Earth, whose light the Sun, the Jupiter and Saturn systems,
/// and the Earth deflect, with the gravitational parameters of DE440. A body the files don't
/// give, or don't give at an instant, throws ``EphemerisError/outsideCoverage``. For a
/// planetary ephemeris alone, ``JPLEphemeris`` names its bodies with an enumeration instead, so
/// that asking for a body it doesn't give doesn't compile.
///
/// States are in kilometers and kilometers per second in the files, and are converted to
/// astronomical units of 149,597,870.7 km. The J2000 frame of the files is taken as the ICRS,
/// as JPL's ephemerides are aligned with the ICRF.
public struct SPKEphemeris: GeocentricEphemeris, Sendable {
	/// A body, by its NAIF ID, with its radius.
	///
	/// The Sun, the Moon, and the planets and their barycenters have the radii of the bodies
	/// of the ``BuiltInEphemeris``; give another body its radius, as from a PCK, a
	/// ``TextKernel``:
	///
	/// ```swift
	/// let pck = try TextKernel(contentsOf: "/path/to/pck00011.tpc")
	/// let ceres = SPKEphemeris.Body(naifID: 2_000_001, radius: pck.radius(of: 2_000_001))
	/// ```
	///
	/// Bodies are equal if their NAIF IDs are, whatever their radii, so that the Sun or the
	/// Earth given its radius is still the ephemeris's Sun or Earth.
	public struct Body: EphemerisBody {
		/// The NAIF ID.
		let id: Int
		/// The body's radius, as for the bodies of the ``BuiltInEphemeris`` or as given, or
		/// `nil` for a point or a body whose radius isn't known.
		public let radius: Distance?

		/// Creates a body from its NAIF ID, with the radius of a body of the
		/// ``BuiltInEphemeris``, or `nil` for another, as an asteroid.
		///
		/// - Parameter naifID: The NAIF ID, as 10 for the Sun, 399 for the Earth, or 2,000,001
		///   for Ceres.
		public init(naifID: Int) {
			id = naifID
			radius = NAIF.radius(of: naifID)
		}

		/// Creates a body from its NAIF ID and its radius.
		///
		/// - Parameters:
		///   - naifID: The NAIF ID, as 2,000,001 for Ceres.
		///   - radius: The equatorial radius, or `nil` for a point or a body whose radius isn't
		///     known.
		public init(naifID: Int, radius: Distance?) {
			id = naifID
			self.radius = radius
		}

		/// The body's NAIF ID.
		public var naifID: Int? {
			id
		}

		public static func == (lhs: Body, rhs: Body) -> Bool {
			lhs.id == rhs.id
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(id)
		}

		/// The solar system barycenter, 0.
		public static let solarSystemBarycenter = Body(naifID: 0)
		/// The barycenter of Mercury, 1.
		public static let mercuryBarycenter = Body(naifID: 1)
		/// The barycenter of Venus, 2.
		public static let venusBarycenter = Body(naifID: 2)
		/// The barycenter of the Earth and the Moon, 3.
		public static let earthMoonBarycenter = Body(naifID: 3)
		/// The barycenter of Mars and its satellites, 4.
		public static let marsBarycenter = Body(naifID: 4)
		/// The barycenter of Jupiter and its satellites, 5.
		public static let jupiterBarycenter = Body(naifID: 5)
		/// The barycenter of Saturn and its satellites, 6.
		public static let saturnBarycenter = Body(naifID: 6)
		/// The barycenter of Uranus and its satellites, 7.
		public static let uranusBarycenter = Body(naifID: 7)
		/// The barycenter of Neptune and its satellites, 8.
		public static let neptuneBarycenter = Body(naifID: 8)
		/// The barycenter of Pluto and its satellites, 9.
		public static let plutoBarycenter = Body(naifID: 9)
		/// The Sun, 10.
		public static let sun = Body(naifID: 10)
		/// Mercury, 199.
		public static let mercury = Body(naifID: 199)
		/// Venus, 299.
		public static let venus = Body(naifID: 299)
		/// The Earth, 399.
		public static let earth = Body(naifID: 399)
		/// The Moon, 301.
		public static let moon = Body(naifID: 301)
		/// Mars, 499.
		public static let mars = Body(naifID: 499)
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

	/// The bodies the files must give relative to the solar system barycenter: the Earth and
	/// the light-deflecting bodies, whose states every observation needs.
	static let requiredBodies = [Body.earth.id] + lightDeflectingBodies.map(\.body.id).filter { $0 != Body.earth.id }

	/// The files, in increasing precedence.
	public let files: [SPKFile]
	/// The instants over which the files give the Earth, the Sun, and the barycenters of the
	/// Jupiter and Saturn systems relative to the solar system barycenter, from the first such
	/// instant to the last.
	///
	/// Other bodies may be given over shorter spans, and an instant within the span at which a
	/// body isn't given, as in a gap between segments, throws
	/// ``EphemerisError/outsideCoverage``.
	public let coverage: ClosedRange<Instant<TDB>>
	/// The segments of the files by target.
	let index: SPKSegmentIndex

	/// Creates an ephemeris from SPK files.
	///
	/// - Parameter files: The files, in increasing precedence: where their segments overlap, a
	///   later file's are used.
	/// - Throws: ``SPKError/missingBody(naifID:)`` if the files don't give the Earth, the Sun,
	///   or the barycenter of the Jupiter or Saturn system relative to the solar system
	///   barycenter at any instant at which they give the others.
	public init(files: [SPKFile]) throws(SPKError) {
		let index = SPKSegmentIndex(files: files)
		coverage = try index.coverage(ofEvery: Self.requiredBodies)
		self.files = files
		self.index = index
	}

	/// Creates an ephemeris from an SPK file, mapped into memory.
	///
	/// - Parameter path: The file's path.
	/// - Throws: An ``SPKError`` if the file can't be read, or doesn't give the Earth or the
	///   Sun relative to the solar system barycenter.
	public init(contentsOf path: String) throws(SPKError) {
		try self.init(files: [SPKFile(contentsOf: path)])
	}

	/// Returns a body's state relative to another body.
	///
	/// - Parameters:
	///   - body: The body.
	///   - origin: The body to which the state is relative.
	///   - tdb: An instant in TDB.
	/// - Returns: The state, in the ICRS.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the files don't give either body, relative to
	///     a body that joins them, at the instant.
	///   - ``EphemerisError/invalidState`` if a segment gives a state that isn't finite.
	public func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
		try index.stateVector(of: body.id, relativeTo: origin.id, at: tdb)
	}
}
