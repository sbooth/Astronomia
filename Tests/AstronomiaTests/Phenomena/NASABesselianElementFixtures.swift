//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Besselian elements of eclipses of the Sun from NASA's eclipse predictions, with the VSOP87 and
/// ELP2000-85 theories and NASA's radii of the Moon and the Sun: the Gregorian date, the hour of
/// TT of the reference time t₀, and the coefficients of the polynomials in the hours from it,
/// valid within 3 hours, of x and y, in equatorial radii of the Earth, the declination d of the
/// axis and the Greenwich hour angle μ, in degrees, and the radii l₁ and l₂ of the penumbra and
/// the umbra on the fundamental plane, and tan f₁ and tan f₂, from
/// https://eclipse.gsfc.nasa.gov/SEbeselm/.
///
/// Eclipse Predictions by Fred Espenak, NASA's GSFC.
let nasaBesselianElements: [(year: Int, month: Int, day: Int, hour: Int, x: [Double], y: [Double], d: [Double], mu: [Double], l1: [Double], l2: [Double], tanF1: Double, tanF2: Double)] = [
	(2016, 3, 9, 2, [-0.062525, 0.5502752, 0.0000046, -0.0000091], [0.253833, 0.1721227, 0.0000171, -0.0000027], [-4.37973, 0.015886, 0.000001], [207.37216, 15.003969], [0.538886, -0.0000704, -0.0000128], [-0.007235, -0.0000700, -0.0000127], 0.0047087, 0.0046852),
	(2024, 4, 8, 18, [-0.318157, 0.5117105, 0.0000326, -0.0000085], [0.219747, 0.2709586, -0.0000594, -0.0000047], [7.58620, 0.014844, -0.000002], [89.59122, 15.004084], [0.535813, 0.0000618, -0.0000128], [-0.010274, 0.0000615, -0.0000127], 0.0046683, 0.0046450),
	(2024, 10, 2, 19, [-0.067968, 0.4416168, 0.0000142, -0.0000049], [-0.363180, -0.2435631, 0.0000339, 0.0000029], [-3.98725, -0.015511, 0.000001], [107.73106, 15.004331], [0.570348, -0.0000002, -0.0000098], [0.024090, -0.0000002, -0.0000097], 0.0046734, 0.0046501),
	(2025, 9, 21, 20, [-0.390002, 0.4531641, 0.0000024, -0.0000064], [-1.001816, -0.2521622, 0.0000456, 0.0000032], [0.36472, -0.015600, -0.000000], [121.78191, 15.004772], [0.562492, 0.0000909, -0.0000102], [0.016273, 0.0000905, -0.0000102], 0.0046583, 0.0046351),
	(2050, 5, 20, 21, [0.254794, 0.5429614, -0.0000125, -0.0000075], [-0.845150, 0.0624711, -0.0000947, -0.0000008], [20.15502, 0.008333, -0.000005], [135.84935, 15.000696], [0.547409, 0.0001108, -0.0000113], [0.001265, 0.0001103, -0.0000112], 0.0046206, 0.0045976),
	(2067, 12, 6, 14, [-0.029780, 0.5543402, 0.0000210, -0.0000081], [0.284988, -0.0089701, 0.0001467, 0.0000000], [-22.53072, -0.004841, 0.000006], [32.25572, 14.997059], [0.550385, -0.0001132, -0.0000119], [0.004226, -0.0001127, -0.0000118], 0.0047450, 0.0047214),
]
