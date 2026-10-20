//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A source of the positions and velocities of solar system bodies.
///
/// An ephemeris gives states in its own frame, as its theory or data defines them, and names
/// the bodies it gives with its own type, so that asking for a body it doesn't give doesn't
/// compile. Ask for a state with ``state(of:relativeTo:at:context:)``, which takes an instant
/// in any timescale:
///
/// ```swift
/// let ephemeris = SolarSystemEphemeris()
/// let mars = try ephemeris.state(of: .mars, relativeTo: .earth, at: instant)
/// ```
///
/// A conforming type implements ``state(of:relativeTo:at:)`` in TDB, and the protocol supplies
/// the conversion from other timescales.
public protocol Ephemeris<Body, Frame>: Sendable {
	/// The bodies the ephemeris gives.
	associatedtype Body: Hashable, Sendable
	/// The frame of the ephemeris's states.
	associatedtype Frame: FixedReferenceFrame

	/// The origin of a state when none is given, the ephemeris's natural center.
	static var defaultOrigin: Body { get }

	/// The TDB instants the ephemeris covers.
	var coverage: ClosedRange<Instant<TDB>> { get }

	/// Returns a body's state relative to another body.
	///
	/// - Parameters:
	///   - body: The body.
	///   - origin: The body to which the state is relative.
	///   - tdb: An instant in TDB.
	/// - Returns: The state, in the ephemeris's frame.
	/// - Throws: ``EphemerisError/outsideCoverage`` if `tdb` is outside ``coverage``.
	func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<Frame>
}

extension Ephemeris {
	/// Returns a body's state relative to another body, at an instant in any timescale.
	///
	/// - Parameters:
	///   - body: The body.
	///   - origin: The body to which the state is relative, by default ``defaultOrigin``.
	///   - instant: An instant, which is converted to TDB.
	///   - context: Observational data for converting `instant` to TDB.
	/// - Returns: The state, in the ephemeris's frame.
	/// - Throws:
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted to TDB.
	///   - ``EphemerisError/outsideCoverage`` if it is outside ``coverage``.
	public func state<Scale: Timescale>(
		of body: Body,
		relativeTo origin: Body = Self.defaultOrigin,
		at instant: Instant<Scale>,
		context: Scale.Context = Scale.defaultContext
	) throws(EphemerisError) -> StateVector<Frame> {
		let tdb: Instant<TDB>
		do throws(TimescaleConversionError) {
			tdb = try instant.converted(to: TDB.self, sourceContext: context)
		}
		catch { throw .timescaleConversion(error) }
		return try state(of: body, relativeTo: origin, at: tdb)
	}
}

/// An ephemeris that gives the Earth, the Sun, and the solar system barycenter, as the
/// positions of bodies seen from the Earth need.
public protocol GeocentricEphemeris: Ephemeris {
	/// The Earth.
	static var earth: Body { get }
	/// The Sun.
	static var sun: Body { get }
	/// The barycenter of the solar system.
	static var solarSystemBarycenter: Body { get }
}
