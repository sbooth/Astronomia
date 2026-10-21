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
		/// The nutation in longitude and obliquity, in radians, corrected to first order for
		/// the pole offsets.
		let nutation: (longitude: Double, obliquity: Double)
		/// The rotation to the true equator and equinox of date.
		let trueEquator: Rotation<ICRS, ICRS>
		/// The rotation to the celestial intermediate reference system.
		let intermediate: Rotation<ICRS, ICRS>
		/// The equation of the origins, in radians.
		let equationOfOrigins: Double

		/// Computes the orientation at a time.
		///
		/// The pole offsets correct the CIP's X and Y, which fixes the intermediate system. The
		/// true equator of date shares its pole, and its origin is the equation of the origins
		/// from the CIO, so it is R3(EO) times the intermediate rotation. The model's s and EO
		/// change by less than a microarcsecond with offsets of a milliarcsecond.
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
			let s = cioLocator(at: t, arguments: arguments, x: x, y: y)
			equationOfOrigins = IAU2006.equationOfOrigins(matrix: model, s: s)
			if let poleOffsets {
				intermediate = celestialToIntermediate(x: x + poleOffsets.dX, y: y + poleOffsets.dY, s: s)
				trueEquator = Rotation<ICRS, ICRS>.aboutZ(Angle(radians: equationOfOrigins)) * intermediate
				// To first order, dX = δΔψ sin ε_A and dY = δΔε.
				nutation = (modelNutation.longitude + poleOffsets.dX / Math.sin(angles.epsilon), modelNutation.obliquity + poleOffsets.dY)
			} else {
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
