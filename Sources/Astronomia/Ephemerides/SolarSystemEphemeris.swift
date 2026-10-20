//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The built-in ephemeris of the solar system, from the planetary solution VSOP2013 and the
/// lunar solution ELP/MPP02, in the ICRS, for J1000.0 to J3000.0.
///
/// ``VSOP2013`` gives the Sun, the planets, and the Earth-Moon barycenter, and a lunar
/// ephemeris, by default ``ELPMPP02/de405``, the geocentric Moon. Each solution's states are
/// rotated from its own ecliptic to the ICRS, and the geocentric Moon divides the barycenter
/// into the Earth and the Moon by the ratio of their masses:
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
/// let ephemeris = SolarSystemEphemeris()
/// let mars = try ephemeris.state(of: .mars, relativeTo: .earth, at: instant)
/// let laserRanging = SolarSystemEphemeris(moon: ELPMPP02.laserRanging)
/// ```
///
/// The truncated series keep the error from truncation near 0.5 mas for the planets and
/// 0.2 mas for the Moon, seen from the Earth. The solutions' own errors are larger far from
/// the present: Chapront and Francou (2003) find ELP/MPP02 within about 1″ in longitude of
/// DE406 from 500 to 2500.
///
/// - Note: VSOP2013 gives the outer planets as the barycenters of their systems, which differ
///   from the planets by up to a few hundred kilometers. Pluto's solution is less accurate
///   than the planets'.
public struct SolarSystemEphemeris: GeocentricEphemeris {
	/// A body of the ephemeris.
	public enum Body: Hashable, Sendable, CaseIterable {
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
	public static let solarSystemBarycenter = Body.solarSystemBarycenter

	/// Returns the geocentric Moon from the lunar ephemeris, in the ICRS.
	let geocentricMoon: @Sendable (Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS>

	public let coverage: ClosedRange<Instant<TDB>>

	/// Creates the ephemeris with the default lunar ephemeris, ``ELPMPP02/de405``.
	public init() {
		self.init(moon: ELPMPP02.de405)
	}

	/// Creates the ephemeris with a lunar ephemeris.
	///
	/// The ephemeris covers the instants that both VSOP2013 and the lunar ephemeris cover.
	///
	/// - Parameter moon: An ephemeris of the Moon relative to the Earth, such as
	///   ``ELPMPP02/laserRanging``.
	public init<Moon: Ephemeris>(moon: Moon) where Moon.Body == ELPMPP02.Body {
		geocentricMoon = { tdb throws(EphemerisError) in
			try moon.state(of: .moon, relativeTo: .earth, at: tdb).converted(to: ICRS.self)
		}
		let planets = Instant<TDB>(builtInEphemerisCoverage.lowerBound) ... Instant<TDB>(builtInEphemerisCoverage.upperBound)
		let lower = max(planets.lowerBound, moon.coverage.lowerBound)
		let upper = max(lower, min(planets.upperBound, moon.coverage.upperBound))
		coverage = lower ... upper
	}

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
			guard let state = VSOP2013.heliocentricState(of: base, at: date),
			      let originState = VSOP2013.heliocentricState(of: originBase, at: date)
			else {
				preconditionFailure("\(date) is outside the coverage of VSOP2013")
			}
			let rotation = VSOP2013.Ecliptic.rotationToICRS
			position = rotation.apply(to: state.position - originState.position)
			velocity = rotation.apply(to: state.velocity - originState.velocity)
		}
		if moonFraction != originMoonFraction {
			let moon = try geocentricMoon(tdb)
			let fraction = moonFraction - originMoonFraction
			position = position + moon.position.vector * fraction
			velocity = velocity + moon.velocity.vector * fraction
		}
		return StateVector(position, velocity)
	}
}

extension SolarSystemEphemeris {
	/// The ratio of the masses of the Earth and the Moon, from INPOP10.
	static let earthMoonMassRatio = 81.300_57
}

extension SolarSystemEphemeris.Body {
	/// The body as a body of VSOP2013 plus a fraction of the geocentric Moon.
	///
	/// The Earth and the Moon are on either side of their barycenter, at distances inversely
	/// proportional to their masses.
	var decomposition: (base: VSOP2013.Body, moonFraction: Double) {
		let ratio = SolarSystemEphemeris.earthMoonMassRatio
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
