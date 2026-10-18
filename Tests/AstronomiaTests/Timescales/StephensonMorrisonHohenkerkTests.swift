//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct StephensonMorrisonHohenkerkTests {
	let model = DeltaTModel.stephensonMorrisonHohenkerk2016
	let spline = DeltaTModel.stephensonMorrisonHohenkerkSpline

	@Test func intervals() {
		#expect(spline.count == 58)
		#expect(spline.first?.start == -720)
		#expect(spline.last?.end == 2019)
		for (a, b) in zip(spline, spline.dropFirst()) {
			// Contiguous, and continuous to the precision of the published coefficients
			#expect(a.end == b.start)
			#expect(abs(a.evaluate(a.end) - b.a0) <= 0.002, "\(a.end)")
		}
	}

	@Test(arguments: [(-720.0, 20371.848), (-100, 11557.668), (1000, 1650.393), (1600, 109.127), (2016, 68.109)])
	func knots(year: Double, deltaT: Double) {
		// At the start of each interval, u = 0 and ΔT is the constant coefficient.
		#expect(model.deltaT(decimalYear: year) == deltaT)
	}

	@Test(arguments: [
		// Table S6 of the supplementary material, to its rounding
		(1800.0, 18.37, 0.005), (1850, 9.34, 0.005), (1900, -1.98, 0.005), (1950, 28.93, 0.005),
		(1990, 56.99, 0.005), (2000, 63.81, 0.005), (2019, 69.24, 0.005),
		(-720, 20370, 5), (-500, 16940, 5), (0, 10440, 5), (1000, 1650, 5), (1500, 290, 5),
	])
	func publishedValues(year: Double, deltaT: Double, tolerance: Double) {
		#expect(abs(model.deltaT(decimalYear: year) - deltaT) <= tolerance)
	}

	@Test func parabolaBeforeSpline() {
		for year in [-2000.0, -721, -1_000_000] {
			let u = (year - 1825) / 100
			#expect(model.deltaT(decimalYear: year) == -10 + 31.4 * u * u)
		}
		// As published, the parabola is about 44 s below the spline at -720, so ΔT steps there.
		let step = model.deltaT(decimalYear: -720) - model.deltaT(decimalYear: -720.000001)
		#expect(abs(step - 44) < 0.1)
	}

	@Test func parabolaTrendAfterSpline() {
		// Continuous at 2019, then rising with the parabola
		let end = spline[spline.count - 1].evaluate(2019)
		#expect(abs(model.deltaT(decimalYear: 2019) - end) <= 1e-9)
		#expect(abs(model.deltaT(decimalYear: 2018.999999) - end) <= 1e-3)
		let parabola = DeltaTModel.stephensonMorrisonHohenkerkParabola
		#expect(abs(model.deltaT(decimalYear: 2050) - (end + parabola(2050) - parabola(2019))) <= 1e-9)
	}

	@Test func agreesWithObservations() throws {
		// The spline follows the observed ΔT closely in recent decades.
		for year in stride(from: 1975.0, through: 2018, by: 1) {
			let tt = try JulianDate(decimalYear: year)
			let observed = try #require(DeltaTTable.modern.deltaT(at: tt))
			#expect(abs(model.deltaT(decimalYear: year) - observed) <= 0.5, "\(year)")
		}
	}

	@Test func differsFromEspenakMeeus() {
		// About -4.4 min at 500 BC and +3.2 min at AD 1300
		let espenakMeeus = DeltaTModel.espenakMeeus2006
		#expect(abs(model.deltaT(decimalYear: -500) - espenakMeeus.deltaT(decimalYear: -500) + 264.0) <= 0.1)
		#expect(abs(model.deltaT(decimalYear: 1300) - espenakMeeus.deltaT(decimalYear: 1300) - 189.2) <= 0.1)
	}
}
