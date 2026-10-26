//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An SPK file, the format of JPL's ephemerides and of NAIF's SPICE kernels.
///
/// An SPK file holds segments, each giving one body's state relative to another over an
/// interval of time, as the planets' barycenters relative to the solar system barycenter, or
/// the Moon relative to the Earth-Moon barycenter. Give one to an ``SPKEphemeris``, or a
/// planetary ephemeris such as DE440 to a ``JPLEphemeris``.
///
/// A file is mapped into memory, so only the parts used are read, and a file of gigabytes, as
/// DE441, costs little memory; files can be mapped on Apple's platforms and Linux. A file's
/// bytes can also be given directly, as from a resource of an app.
///
/// ```swift
/// let de440 = try SPKFile(contentsOf: "/path/to/de440.bsp")
/// for segment in de440.segments {
/// 	print(segment.target, segment.center, segment.coverage)
/// }
/// ```
///
/// Segments of types 2 and 3, the Chebyshev polynomials of JPL's planetary ephemerides, in the
/// J2000 frame, the ICRF, can be evaluated; others are listed but not used.
public struct SPKFile: Sendable {
	/// A segment of an SPK file: one body's state relative to another over an interval of time.
	public struct Segment: Hashable, Sendable {
		/// The NAIF ID of the body whose state the segment gives.
		public let target: Int
		/// The NAIF ID of the body to which the state is relative.
		public let center: Int
		/// The NAIF ID of the frame of the state: 1 for J2000, taken as the ICRF.
		public let frame: Int
		/// The SPK data type: 2 or 3 for Chebyshev polynomials.
		public let type: Int
		/// The instants the segment covers.
		public let coverage: ClosedRange<Instant<TDB>>
		/// Whether the segment can be evaluated: of type 2 or 3, in the J2000 frame.
		public var isSupported: Bool {
			(type == 2 || type == 3) && frame == 1
		}
	}

	/// The file's contents.
	let kernel: SPKKernel
	/// The segments, in the order of the file.
	public let segments: [Segment]

	/// Maps an SPK file into memory.
	///
	/// - Parameter path: The file's path.
	/// - Throws: An ``SPKError``: ``SPKError/cannotOpenFile(errno:)`` if the file can't be
	///   opened or mapped, or another if it isn't a valid SPK file.
	public init(contentsOf path: String) throws(SPKError) {
		try self.init(data: KernelData(mapping: path))
	}

	/// Reads an SPK file from its bytes, which are copied.
	///
	/// - Parameter bytes: The file's bytes.
	/// - Throws: An ``SPKError`` if the bytes aren't a valid SPK file.
	public init(bytes: some Collection<UInt8>) throws(SPKError) {
		try self.init(data: KernelData(copying: bytes))
	}

	/// Reads an SPK file from its data.
	init(data: KernelData) throws(SPKError) {
		kernel = try SPKKernel(data: data)
		var segments: [Segment] = []
		for segment in kernel.segments {
			guard let start = segment.start.tdbInstant, let end = segment.end.tdbInstant else {
				throw .invalidFile
			}
			segments.append(Segment(target: segment.target, center: segment.center, frame: segment.frame, type: segment.type, coverage: start ... end))
		}
		self.segments = segments
	}
}

extension Double {
	/// The instant of a number of TDB seconds from J2000.0, or `nil` if it can't be
	/// represented.
	var tdbInstant: Instant<TDB>? {
		guard let julianDate = try? JulianDate(daysSinceJ2000: self / secondsPerDay) else { return nil }
		return Instant(julianDate)
	}
}

extension Instant where Scale == TDB {
	/// The TDB seconds from J2000.0, as an SPK file gives time.
	var secondsSinceJ2000: Double {
		(Double(julianDate.julianDayNumber - JulianDate.j2000.julianDayNumber) + julianDate.fractionFromNoon) * secondsPerDay
	}
}

/// The segments of SPK files that can be evaluated, by target, for the states of bodies
/// relative to each other.
///
/// A body's state relative to another is found along the chains of segments from each toward
/// the solar system barycenter: the body relative to its center, the center relative to its
/// own, and so on. The chains are joined where they first meet, so the Moon relative to the
/// Earth uses only their segments relative to the Earth-Moon barycenter. Where segments overlap,
/// as SPICE does, a later file takes precedence over an earlier one, and a later segment in a
/// file over an earlier one.
struct SPKSegmentIndex: Sendable {
	/// A segment and the file it is in.
	struct Link: Sendable {
		/// The file.
		let kernel: SPKKernel
		/// The segment.
		let segment: SPKSegment
	}

	/// The segments that can be evaluated by target, in the order of precedence.
	let links: [Int: [Link]]

	/// The allowance, in seconds, at the ends of a segment's interval, for the rounding of an
	/// instant to and from TDB seconds; the polynomials extend smoothly over it.
	static let allowance = 1e-3

	/// The longest chain followed, against a file whose segments form a cycle.
	static let longestChain = 32

	/// Indexes the segments of files.
	///
	/// - Parameter files: The files, in increasing precedence.
	init(files: [SPKFile]) {
		var links: [Int: [Link]] = [:]
		for file in files.reversed() {
			for segment in file.kernel.segments.reversed() where segment.chebyshev != nil && segment.frame == 1 {
				links[segment.target, default: []].append(Link(kernel: file.kernel, segment: segment))
			}
		}
		self.links = links
	}

	/// Returns the segment that gives a body at an instant, or `nil` if none does.
	func link(for body: Int, at seconds: Double) -> Link? {
		links[body]?.first { $0.segment.start - Self.allowance <= seconds && seconds <= $0.segment.end + Self.allowance }
	}

	/// Returns the chain from a body toward the solar system barycenter at an instant: the
	/// bodies, from the body itself, and the segment giving each relative to the next.
	func chain(from body: Int, at seconds: Double) -> (bodies: [Int], links: [Link]) {
		var bodies = [body]
		var links: [Link] = []
		var current = body
		while current != 0, bodies.count < Self.longestChain, let link = link(for: current, at: seconds) {
			current = link.segment.center
			guard !bodies.contains(current) else { break }
			links.append(link)
			bodies.append(current)
		}
		return (bodies, links)
	}

	/// Returns a body's state relative to another, in kilometers and kilometers per second, or
	/// `nil` if the segments don't join the two at the instant.
	func state(of body: Int, relativeTo origin: Int, at seconds: Double) -> (position: Vector3, velocity: Vector3)? {
		let target = chain(from: body, at: seconds)
		let center = chain(from: origin, at: seconds)
		guard let i = target.bodies.firstIndex(where: center.bodies.contains), let j = center.bodies.firstIndex(of: target.bodies[i]) else {
			return nil
		}
		var position = Vector3.zero
		var velocity = Vector3.zero
		for link in target.links.prefix(i) {
			let state = link.kernel.state(of: link.segment, at: seconds)
			position = position + state.position
			velocity = velocity + state.velocity
		}
		for link in center.links.prefix(j) {
			let state = link.kernel.state(of: link.segment, at: seconds)
			position = position - state.position
			velocity = velocity - state.velocity
		}
		return (position, velocity)
	}

	/// Returns the TDB seconds over which a body is given relative to the solar system
	/// barycenter, along the chain of its segments of highest precedence, or `nil` if it isn't.
	///
	/// Each link's span is that of all the body's segments to the same center, so a gap
	/// between them is within the span.
	func coverage(of body: Int) -> ClosedRange<Double>? {
		var current = body
		var span = -Double.infinity ... Double.infinity
		var visited: Set<Int> = [body]
		while current != 0 {
			guard let first = links[current]?.first else { return nil }
			let center = first.segment.center
			let segments = links[current, default: []].filter { $0.segment.center == center }
			let start = segments.map(\.segment.start).min() ?? first.segment.start
			let end = segments.map(\.segment.end).max() ?? first.segment.end
			guard start <= span.upperBound, end >= span.lowerBound, visited.insert(center).inserted else { return nil }
			span = max(start, span.lowerBound) ... min(end, span.upperBound)
			current = center
		}
		return span
	}
}

/// The gravitational parameters of DE440 (Park et al. 2021), in au³/day², for the bodies whose
/// gravity deflects light.
enum DE440GravitationalParameters {
	/// Converts km³/s² to au³/day².
	private static func convert(_ kilometersCubedPerSecondSquared: Double) -> Double {
		kilometersCubedPerSecondSquared * (secondsPerDay * secondsPerDay) / (kilometersPerAstronomicalUnit * kilometersPerAstronomicalUnit * kilometersPerAstronomicalUnit)
	}

	/// The Sun.
	static let sun = convert(132_712_440_041.279_419)
	/// The Jupiter system.
	static let jupiterSystem = convert(126_712_764.1)
	/// The Saturn system.
	static let saturnSystem = convert(37_940_584.841_8)
	/// The Earth.
	static let earth = convert(398_600.435_507)
}

extension SPKSegmentIndex {
	/// Returns a state from the index as a state vector in the ICRS, in au and au/day.
	///
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the segments don't join the bodies at the
	///     instant.
	///   - ``EphemerisError/invalidState`` if the state isn't finite.
	func stateVector(of body: Int, relativeTo origin: Int, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
		guard let (position, velocity) = state(of: body, relativeTo: origin, at: tdb.secondsSinceJ2000) else {
			throw .outsideCoverage
		}
		let state = StateVector<ICRS>(position * (1 / kilometersPerAstronomicalUnit), velocity * (secondsPerDay / kilometersPerAstronomicalUnit))
		guard [position.x, position.y, position.z, velocity.x, velocity.y, velocity.z].allSatisfy(\.isFinite) else {
			throw .invalidState
		}
		return state
	}
}
