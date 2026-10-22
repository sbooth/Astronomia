//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension IAU2006 {
	/// The rotations from the GCRS to the celestial frames of date at one instant, with the
	/// observed celestial pole offsets applied if given.
	struct Orientation: Sendable {
		/// The Fukushima-Williams angles and mean obliquity.
		let angles: PrecessionAngles
		/// The nutation in longitude and obliquity, in radians, corrected for the pole offsets.
		let nutation: (longitude: Double, obliquity: Double)
		/// The rotation to the true equator and equinox of date.
		let trueEquator: Rotation<ICRS, ICRS>
		/// The rotation to the celestial intermediate reference system.
		let intermediate: Rotation<ICRS, ICRS>
		/// The equation of the origins, in radians.
		let equationOfOrigins: Double
		/// The X and Y coordinates of the CIP, in radians, corrected for the pole offsets.
		let pole: (x: Double, y: Double)
		/// The CIO locator s, in radians.
		let s: Double

		/// Computes the orientation at a time.
		///
		/// The pole offsets correct the CIP's X and Y, which fixes the intermediate system. They
		/// also move the true equinox along the equator, by about δΔψ cos ε_A, so the equation
		/// of the origins comes from the bias-precession-nutation matrix with the nutation
		/// corrected for them. The true equator of date, which shares the CIP, is R3(EO) times
		/// the intermediate rotation. The model's s changes by less than a nanoarcsecond.
		///
		/// - Parameters:
		///   - t: TT in Julian centuries from J2000.0.
		///   - poleOffsets: dX and dY, in radians, or `nil` for the model alone.
		init(at t: Double, poleOffsets: (dX: Double, dY: Double)?) {
			let arguments = FundamentalArguments(at: t)
			angles = precessionAngles(at: t)
			let modelNutation = IAU2006.nutation(at: t, arguments: arguments)
			let model = biasPrecessionNutation(angles: angles, nutation: modelNutation)
			let x = model.storage.2.x
			let y = model.storage.2.y
			s = cioLocator(at: t, arguments: arguments, x: x, y: y)
			if let poleOffsets {
				nutation = correctedNutation(modelNutation, angles: angles, pole: (x, y), poleOffsets: poleOffsets)
				let corrected = biasPrecessionNutation(angles: angles, nutation: nutation)
				equationOfOrigins = IAU2006.equationOfOrigins(matrix: corrected, s: s)
				pole = (x + poleOffsets.dX, y + poleOffsets.dY)
				intermediate = celestialToIntermediate(x: pole.x, y: pole.y, s: s)
				trueEquator = Rotation<ICRS, ICRS>.aboutZ(Angle(radians: equationOfOrigins)) * intermediate
			} else {
				equationOfOrigins = IAU2006.equationOfOrigins(matrix: model, s: s)
				pole = (x, y)
				intermediate = celestialToIntermediate(x: x, y: y, s: s)
				trueEquator = model
				nutation = modelNutation
			}
		}

		/// The rotation to the true ecliptic and equinox of date, R1(ε_A + Δε) times the
		/// rotation to the true equator.
		var trueEcliptic: Rotation<ICRS, ICRS> {
			Rotation<ICRS, ICRS>.aboutX(Angle(radians: angles.epsilon + nutation.obliquity)) * trueEquator
		}
	}

	/// Returns the nutation corrected for celestial pole offsets: the nutation whose
	/// bias-precession-nutation matrix has the corrected pole, X + dX and Y + dY.
	///
	/// To first order dX = δΔψ sin ε_A and dY = δΔε (IERS Conventions (2010), Section 5.5.4),
	/// but far from J2000.0 the precession couples them by several percent. Newton's method,
	/// with the pole's derivatives by differences, solves for the corrections to a
	/// nanoarcsecond in two steps, without evaluating the series again.
	///
	/// - Parameters:
	///   - nutation: The model's nutation in longitude and obliquity, in radians.
	///   - angles: The Fukushima-Williams angles and mean obliquity.
	///   - pole: The model's X and Y of the CIP, in radians.
	///   - poleOffsets: dX and dY, in radians.
	/// - Returns: The corrected nutation, in radians.
	static func correctedNutation(_ nutation: (longitude: Double, obliquity: Double), angles: PrecessionAngles, pole: (x: Double, y: Double), poleOffsets: (dX: Double, dY: Double)) -> (longitude: Double, obliquity: Double) {
		/// Returns the X and Y of the CIP for a nutation.
		func cip(_ longitude: Double, _ obliquity: Double) -> (x: Double, y: Double) {
			let row = biasPrecessionNutation(angles: angles, nutation: (longitude, obliquity)).storage.2
			return (row.x, row.y)
		}
		let target = (x: pole.x + poleOffsets.dX, y: pole.y + poleOffsets.dY)
		// The derivatives of X and Y with respect to Δψ and Δε
		let h = 1e-7
		let base = cip(nutation.longitude, nutation.obliquity)
		let byLongitude = cip(nutation.longitude + h, nutation.obliquity)
		let byObliquity = cip(nutation.longitude, nutation.obliquity + h)
		let (a, b) = ((byLongitude.x - base.x) / h, (byObliquity.x - base.x) / h)
		let (c, d) = ((byLongitude.y - base.y) / h, (byObliquity.y - base.y) / h)
		let determinant = a * d - b * c
		var longitude = nutation.longitude
		var obliquity = nutation.obliquity
		for _ in 0 ..< 2 {
			let current = cip(longitude, obliquity)
			let (ex, ey) = (target.x - current.x, target.y - current.y)
			longitude = longitude + (d * ex - b * ey) / determinant
			obliquity = obliquity + (a * ey - c * ex) / determinant
		}
		return (longitude, obliquity)
	}

	/// Returns the rotation from the GCRS to the mean equator and equinox of date, the product
	/// of the frame bias and precession: R1(-ε_A) R3(-ψ̄) R1(φ̄) R3(γ̄).
	///
	/// - Parameter angles: The Fukushima-Williams angles.
	static func biasPrecession(angles: PrecessionAngles) -> Rotation<ICRS, ICRS> {
		biasPrecessionNutation(angles: angles, nutation: (0, 0))
	}

	/// Returns the rotation from the GCRS to the mean ecliptic and equinox of date, R1(ε_A)
	/// times the frame bias and precession, which is R3(-ψ̄) R1(φ̄) R3(γ̄).
	///
	/// - Parameter angles: The Fukushima-Williams angles.
	static func meanEcliptic(angles: PrecessionAngles) -> Rotation<ICRS, ICRS> {
		typealias R = Rotation<ICRS, ICRS>
		return R.aboutZ(Angle(radians: -angles.psi)) * R.aboutX(Angle(radians: angles.phi)) * R.aboutZ(Angle(radians: angles.gamma))
	}

	/// Returns the rotation from the GCRS to the celestial intermediate reference system,
	/// following `eraC2ixys` of ERFA: R3(-(E + s)) R2(d) R3(E), where X = sin d cos E and
	/// Y = sin d sin E.
	///
	/// - Parameters:
	///   - x: The X coordinate of the CIP, in radians.
	///   - y: The Y coordinate of the CIP, in radians.
	///   - s: The CIO locator, in radians.
	static func celestialToIntermediate(x: Double, y: Double, s: Double) -> Rotation<ICRS, ICRS> {
		typealias R = Rotation<ICRS, ICRS>
		let r2 = x * x + y * y
		let e = r2 > 0 ? Math.atan2(y, x) : 0
		let d = Math.atan((r2 / (1 - r2)).squareRoot())
		return R.aboutZ(Angle(radians: -(e + s))) * R.aboutY(Angle(radians: d)) * R.aboutZ(Angle(radians: e))
	}
}

extension IAU2006.Orientation {
	/// Computes the orientation at an instant.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: Observed Earth orientation, whose pole offsets are applied where its
	///     table covers `tt`.
	init(at tt: Instant<TT>, earthOrientation: EarthOrientation) {
		self.init(at: tt.julianDate.julianCenturiesSinceJ2000, poleOffsets: earthOrientation.poleOffsets(at: tt))
	}
}

extension IAU2006 {
	/// Returns the TIO locator s', which places the terrestrial intermediate origin on the
	/// CIP's equator: -47 µas per century, the approximation of the IERS Conventions (2010),
	/// Eq. (5.13).
	///
	/// - Parameter t: TT in Julian centuries from J2000.0.
	/// - Returns: s', in radians.
	static func tioLocator(at t: Double) -> Double {
		-47e-6 * t / arcsecondsPerRadian
	}

	/// Returns the polar motion matrix W, the rotation from the terrestrial intermediate
	/// reference system to the ITRS, following `eraPom00` of ERFA: R1(-y_p) R2(-x_p) R3(s').
	///
	/// - Parameters:
	///   - x: The x coordinate of the pole, x_p, in radians.
	///   - y: The y coordinate of the pole, y_p, in radians.
	///   - sPrime: The TIO locator s', in radians.
	static func polarMotion(x: Double, y: Double, sPrime: Double) -> Rotation<ICRS, ICRS> {
		typealias R = Rotation<ICRS, ICRS>
		return R.aboutX(Angle(radians: -y)) * R.aboutY(Angle(radians: -x)) * R.aboutZ(Angle(radians: sPrime))
	}

	/// Returns the rotation from the GCRS to the terrestrial intermediate reference system,
	/// R3(ERA) times the rotation to the CIRS.
	///
	/// - Parameters:
	///   - tt: The instant in TT.
	///   - ut1: The same instant in UT1.
	///   - earthOrientation: Observed Earth orientation to apply.
	static func terrestrialIntermediate(at tt: Instant<TT>, ut1: Instant<UT1>, earthOrientation: EarthOrientation) -> Rotation<ICRS, ICRS> {
		let intermediate = Orientation(at: tt, earthOrientation: earthOrientation).intermediate
		return Rotation<ICRS, ICRS>.aboutZ(EarthRotation.earthRotationAngle(ut1: ut1.julianDate)) * intermediate
	}

	/// Returns the polar motion matrix W at an instant, from the Earth orientation's polar
	/// motion and the TIO locator.
	///
	/// - Parameters:
	///   - tt: The instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	static func polarMotion(at tt: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, ICRS> {
		let (x, y) = earthOrientation.polarMotion(at: tt)
		return polarMotion(x: x, y: y, sPrime: tioLocator(at: tt.julianDate.julianCenturiesSinceJ2000))
	}
}
