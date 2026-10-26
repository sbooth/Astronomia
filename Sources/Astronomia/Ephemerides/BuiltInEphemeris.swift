//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The built-in ephemeris of the solar system, from the planetary solution VSOP2013 and the
/// lunar solution ELP/MPP02, in the ICRS, for J1000.0 to J3000.0.
///
/// ``VSOP2013`` gives the Sun, the planets, and the Earth-Moon barycenter, and a fit of
/// ``ELPMPP02``, by default ``ELPMPP02/de405``, the geocentric Moon. Each solution's states
/// are rotated from its own ecliptic to the ICRS, and the geocentric Moon divides the
/// barycenter into the Earth and the Moon by the ratio of their masses:
///
/// ```swift
/// let earth = barycenter - geocentricMoon * (1 / (1 + μ))
/// let moon = barycenter + geocentricMoon * (μ / (1 + μ))
/// ```
///
/// where μ is the ratio of the masses of the Earth and the Moon, 81.30057, from INPOP10, to
/// which VSOP2013 is fitted. States are relative to the solar system barycenter unless another
/// origin is given.
///
/// ```swift
/// let ephemeris = BuiltInEphemeris()
/// let mars = try ephemeris.state(of: .mars, relativeTo: .earth, at: instant)
/// let laserRanging = BuiltInEphemeris(lunarFit: .laserRanging)
/// let fast = BuiltInEphemeris(precision: .arcsecond)
/// ```
///
/// The truncated series keep the error from truncation near 0.5 mas for the planets and
/// 0.2 mas for the Moon, seen from the Earth. A coarser ``SeriesPrecision`` sums fewer terms, for
/// an error within its bound in a fraction of the time. The solutions' own errors are larger far
/// from the present: Chapront and Francou (2003) find ELP/MPP02 within about 1" in longitude of
/// DE406 from 500 to 2500.
///
/// - Note: VSOP2013 gives the outer planets as the barycenters of their systems, which differ
///   from the planets by up to a few hundred kilometers. Pluto's solution is less accurate
///   than the planets'.
public struct BuiltInEphemeris: GeocentricEphemeris, Hashable {
	/// A body of the ephemeris.
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
		/// Mars.
		case mars
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
	}

	public typealias Frame = ICRS

	/// The solar system barycenter.
	public static let defaultOrigin = Body.solarSystemBarycenter
	public static let earth = Body.earth
	public static let sun = Body.sun
	/// The Sun, the barycenters of Jupiter and Saturn, and the Earth, with their gravitational
	/// parameters from INPOP10a as given in VSOP2013.f and their radii, as ``Body/radius`` gives
	/// them. The Earth deflects light only for an observer on its surface.
	public static let lightDeflectingBodies = [
		LightDeflectingBody(uncheckedBody: Body.sun, gravitationalParameter: VSOP2013.sunGravitationalParameter),
		LightDeflectingBody(uncheckedBody: Body.jupiterBarycenter, gravitationalParameter: VSOP2013.Body.jupiterBarycenter.gravitationalParameter ?? 0),
		LightDeflectingBody(uncheckedBody: Body.saturnBarycenter, gravitationalParameter: VSOP2013.Body.saturnBarycenter.gravitationalParameter ?? 0),
		LightDeflectingBody(uncheckedBody: Body.earth, gravitationalParameter: (VSOP2013.Body.earthMoonBarycenter.gravitationalParameter ?? 0) * earthMoonMassRatio / (1 + earthMoonMassRatio)),
	]
	public static let solarSystemBarycenter = Body.solarSystemBarycenter

	/// A fit of the lunar solution ELP/MPP02.
	public enum LunarFit: Hashable, Sendable, CaseIterable {
		/// ``ELPMPP02/de405``, the fit to DE405, the default.
		case de405
		/// ``ELPMPP02/laserRanging``, the fit to lunar laser ranging.
		case laserRanging
	}

	/// The fit of the lunar solution.
	public let lunarFit: LunarFit
	/// The precision level of the series.
	public let precision: SeriesPrecision

	/// Creates the ephemeris.
	///
	/// - Parameters:
	///   - lunarFit: The fit of the lunar solution, by default ``LunarFit/de405``.
	///   - precision: The precision level of the series, by default ``SeriesPrecision/full``.
	public init(lunarFit: LunarFit = .de405, precision: SeriesPrecision = .full) {
		self.lunarFit = lunarFit
		self.precision = precision
	}

	public var coverage: ClosedRange<Instant<TDB>> { builtInEphemerisInstants }

	public func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
		guard coverage.contains(tdb) else { throw .outsideCoverage }
		// Each body is a body of VSOP2013 plus a fraction of the geocentric Moon, so only the
		// parts that don't cancel are evaluated: the Moon from the Earth is ELP/MPP02 alone,
		// and Venus from Saturn is VSOP2013 alone.
		let date = tdb.julianDate
		let (base, moonFraction) = body.decomposition
		let (originBase, originMoonFraction) = origin.decomposition
		var position = Vector3.zero
		var velocity = Vector3.zero
		if base != originBase {
			guard let state = VSOP2013.heliocentricState(of: base, at: date, precision: precision),
			      let originState = VSOP2013.heliocentricState(of: originBase, at: date, precision: precision)
			else {
				preconditionFailure("\(date) is outside the coverage of VSOP2013")
			}
			let rotation = VSOP2013.Ecliptic.rotationToICRS
			position = rotation.apply(to: state.position - originState.position)
			velocity = rotation.apply(to: state.velocity - originState.velocity)
		}
		if moonFraction != originMoonFraction {
			// The coverage of ELP/MPP02 is that of VSOP2013, checked above.
			guard let moon = geocentricMoon(at: date) else {
				preconditionFailure("\(date) is outside the coverage of ELP/MPP02")
			}
			let fraction = moonFraction - originMoonFraction
			position = position + moon.position * fraction
			velocity = velocity + moon.velocity * fraction
		}
		return StateVector(position, velocity)
	}
}

extension BuiltInEphemeris {
	/// The ratio of the masses of the Earth and the Moon, from INPOP10.
	static let earthMoonMassRatio = 81.300_57

	/// Returns the geocentric Moon from the lunar solution, in the ICRS.
	///
	/// - Parameter tdb: A Julian Date in TDB.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside the coverage.
	func geocentricMoon(at tdb: JulianDate) -> (position: Vector3, velocity: Vector3)? {
		switch lunarFit {
		case .de405: ELPMPP02.DE405(precision: precision).icrsState(at: tdb)
		case .laserRanging: ELPMPP02.LaserRanging(precision: precision).icrsState(at: tdb)
		}
	}
}

extension BuiltInEphemeris.Body {
	/// The body's NAIF ID: 0 for the solar system barycenter, 10 for the Sun, 199, 299, 399,
	/// and 499 for Mercury, Venus, the Earth, and Mars, 301 for the Moon, and 3 and 5 to 9 for
	/// the barycenters of the Earth and the Moon and of the outer planets' systems.
	public var naifID: Int? {
		switch self {
		case .solarSystemBarycenter: 0
		case .sun: 10
		case .mercury: 199
		case .venus: 299
		case .earthMoonBarycenter: 3
		case .earth: 399
		case .moon: 301
		case .mars: 499
		case .jupiterBarycenter: 5
		case .saturnBarycenter: 6
		case .uranusBarycenter: 7
		case .neptuneBarycenter: 8
		case .plutoBarycenter: 9
		}
	}

	/// The body's radius: the Sun's nominal radius of IAU 2015 Resolution B3, the Moon's mean
	/// radius, the Earth's WGS84 equatorial radius, and the other planets' equatorial radii from
	/// the IAU Working Group on Cartographic Coordinates and Rotational Elements, 2015 (Archinal
	/// et al. 2018), for the gas giants at the 1 bar level. The barycenters of the outer
	/// planets' systems take their planets' radii, and the solar system and Earth-Moon
	/// barycenters are points.
	public var radius: Distance? {
		naifID.flatMap(NAIF.radius(of:))
	}

	/// The body as a body of VSOP2013 plus a fraction of the geocentric Moon.
	///
	/// The Earth and the Moon are on either side of their barycenter, at distances inversely
	/// proportional to their masses.
	var decomposition: (base: VSOP2013.Body, moonFraction: Double) {
		let ratio = BuiltInEphemeris.earthMoonMassRatio
		switch self {
		case .solarSystemBarycenter: return (.solarSystemBarycenter, 0)
		case .sun: return (.sun, 0)
		case .mercury: return (.mercury, 0)
		case .venus: return (.venus, 0)
		case .earthMoonBarycenter: return (.earthMoonBarycenter, 0)
		case .earth: return (.earthMoonBarycenter, -1 / (1 + ratio))
		case .moon: return (.earthMoonBarycenter, ratio / (1 + ratio))
		case .mars: return (.mars, 0)
		case .jupiterBarycenter: return (.jupiterBarycenter, 0)
		case .saturnBarycenter: return (.saturnBarycenter, 0)
		case .uranusBarycenter: return (.uranusBarycenter, 0)
		case .neptuneBarycenter: return (.neptuneBarycenter, 0)
		case .plutoBarycenter: return (.plutoBarycenter, 0)
		}
	}
}
