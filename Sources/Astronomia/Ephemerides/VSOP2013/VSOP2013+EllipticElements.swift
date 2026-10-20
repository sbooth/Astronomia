//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension VSOP2013 {
	/// The elliptic elements of the VSOP planetary theories.
	///
	/// The elements avoid the singularities of the classical elements at zero eccentricity and
	/// inclination. With e the eccentricity, ϖ the longitude of perihelion, i the inclination, and
	/// Ω the longitude of the ascending node: k = e cos ϖ, h = e sin ϖ, q = sin(i/2) cos Ω, and
	/// p = sin(i/2) sin Ω.
	struct EllipticElements: Hashable, Sendable {
		/// The semimajor axis, in astronomical units.
		let a: Double
		/// The mean longitude, in radians.
		let meanLongitude: Double
		/// e cos ϖ.
		let k: Double
		/// e sin ϖ.
		let h: Double
		/// sin(i/2) cos Ω.
		let q: Double
		/// sin(i/2) sin Ω.
		let p: Double
	}
}

extension VSOP2013.EllipticElements {
	/// Returns the position and velocity of the elliptic orbit at these elements, in the frame
	/// of the elements.
	///
	/// This follows `ELLXYZ` of `VSOP2013.f`, solving Kepler's equation for the eccentric
	/// longitude by Newton's method. The velocity is that of the two-body orbit with these
	/// elements, as in `ELLXYZ`, not the derivative of the series.
	///
	/// - Parameter gm: The gravitational parameter of the Sun and the body together, in
	///   au³/day².
	/// - Returns: The position, in astronomical units, and the velocity, in astronomical units
	///   per day.
	func state(gm: Double) -> (position: Vector3, velocity: Vector3) {
		let fi = (1 - k * k - h * h).squareRoot()
		let ki = (1 - q * q - p * p).squareRoot()
		let u = 1 / (1 + fi)
		let e = (k * k + h * h).squareRoot()
		let e2 = e * e
		let e3 = e2 * e
		let twoPi = 2 * Double.pi
		let l = meanLongitude.truncatingRemainder(dividingBy: twoPi)
		let m = l - Math.atan2(h, k)

		// The eccentric longitude F, from a series start and Newton's method on
		// L = F - k sin F + h cos F, written with z̄ e^{iF} as VSOP2013.f writes it.
		var f = l + (e - 0.125 * e3) * Math.sin(m) + 0.5 * e2 * Math.sin(2 * m) + 0.375 * e3 * Math.sin(3 * m)
		var (sinF, cosF) = (0.0, 0.0)
		var z3 = (re: 0.0, im: 0.0)
		var rsa = 0.0
		for _ in 0 ..< 32 {
			(sinF, cosF) = Math.sincos(f)
			// z̄ = k - ih, times e^{iF}
			z3 = (re: k * cosF + h * sinF, im: k * sinF - h * cosF)
			let dl = l - f + z3.im
			rsa = 1 - z3.re
			f += dl / rsa
			if Swift.abs(dl) < 1e-15 {
				break
			}
		}

		// The values of the last iteration, before its correction, as in VSOP2013.f
		let z1 = (re: u * k * z3.im, im: u * h * z3.im)
		let z2 = (re: z1.im, im: -z1.re)
		let cw = (-k + cosF + z2.re) / rsa
		let sw = (-h + sinF + z2.im) / rsa
		let xm = p * cw - q * sw
		let r = a * rsa

		let position = Vector3(r * (cw - 2 * p * xm), r * (sw + 2 * q * xm), -2 * r * ki * xm)

		let ms = a * (h + sw) / fi
		let mc = a * (k + cw) / fi
		let n = gm.squareRoot() / (a * a.squareRoot())
		let velocity = Vector3(
			n * ((2 * p * p - 1) * ms + 2 * p * q * mc),
			n * ((1 - 2 * q * q) * mc - 2 * p * q * ms),
			2 * n * ki * (p * ms + q * mc)
		)
		return (position, velocity)
	}
}
