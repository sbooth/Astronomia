//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct NamedStarTests {
	@Test func epochIsJ1991_25() throws {
		let epoch = try JulianDate(julianEpoch: 1991.25)
		#expect(NamedStar.hipparcosEpoch == Instant(epoch))
	}

	@Test func starsAreInOrderOfTheirNamesAndUnique() {
		let all = NamedStar.all
		#expect(all.count > 500)
		let keys = all.map { $0.asciiName.lowercased() }
		#expect(zip(keys, keys.dropFirst()).allSatisfy { $0 < $1 })
		#expect(Set(all.map(\.name)).count == all.count)
	}

	@Test func starsAreValid() throws {
		for named in NamedStar.all {
			let star = named.star
			let checked = try Star(
				rightAscension: star.rightAscension,
				declination: star.declination,
				properMotionInRightAscension: star.properMotionInRightAscension,
				properMotionInDeclination: star.properMotionInDeclination,
				parallax: star.parallax,
				radialVelocity: star.radialVelocity,
				epoch: star.epoch)
			#expect(checked == star, "\(named.name)")
			#expect(star.rightAscension.radians >= 0 && star.rightAscension.radians < 2 * .pi, "\(named.name)")
			#expect(star.epoch == NamedStar.hipparcosEpoch)
			#expect(named.hipparcosNumber > 0 && named.hipparcosNumber <= 120_404, "\(named.name)")
			#expect(named.constellation.count == 3, "\(named.name)")
			#expect(!named.designation.isEmpty, "\(named.name)")
			#expect(named.asciiName.allSatisfy { $0.isASCII }, "\(named.name)")
			#expect(named.bayerDesignation.map { !$0.isEmpty } ?? true, "\(named.name)")
		}
	}

	@Test func vegaHasTheValuesOfItsCatalogs() throws {
		let vega = try #require(NamedStar.named("Vega"))
		#expect(vega.name == "Vega")
		#expect(vega.designation == "HR 7001")
		#expect(vega.bayerDesignation == "α Lyr")
		#expect(vega.constellation == "Lyr")
		#expect(vega.hipparcosNumber == 91262)
		#expect(vega.brightStarNumber == 7001)
		#expect(vega.hipparcosMagnitude == 0.0868)
		// hip2.dat
		#expect(vega.star.rightAscension.radians == 4.8735545728)
		#expect(vega.star.declination.radians == 0.6768909262)
		#expect(vega.star.parallax == .milliarcseconds(130.23))
		#expect(vega.star.properMotionInRightAscension == .milliarcseconds(200.94))
		#expect(vega.star.properMotionInDeclination == .milliarcseconds(286.23))
		// The Bright Star Catalogue
		#expect(vega.star.radialVelocity == .kilometersPerSecond(-14))
	}

	@Test func starsOutsideTheBrightStarCatalogueHaveNoRadialVelocity() throws {
		let barnard = try #require(NamedStar.named("Barnard's Star"))
		#expect(barnard.designation == "GJ 699")
		#expect(barnard.bayerDesignation == "V2500 Oph")
		#expect(barnard.hipparcosNumber == 87937)
		#expect(barnard.brightStarNumber == nil)
		#expect(barnard.star.parallax == .milliarcseconds(548.31))
		#expect(barnard.star.radialVelocity == .zero)

		let monch = try #require(NamedStar.named("Mönch"))
		#expect(monch.bayerDesignation == nil)
		#expect(monch.brightStarNumber == nil)
	}

	@Test func everyStarIsFoundByItsNames() {
		for (index, star) in NamedStar.all.enumerated() {
			#expect(NamedStar.all[index] == star)
			#expect(NamedStar.named(star.name) == star, "\(star.name)")
			#expect(NamedStar.named(star.asciiName) == star, "\(star.name)")
		}
	}

	@Test func namesMatchWithoutCaseOrDiacritics() throws {
		let monch = try #require(NamedStar.named("Mönch"))
		#expect(monch.name == "Mönch")
		#expect(NamedStar.named("monch") == monch)
		#expect(NamedStar.named("MONCH") == monch)
		#expect(NamedStar.named("MÖNCH") == monch)
		// The decomposed form of the name
		#expect(NamedStar.named("Mo\u{308}nch") == monch)
		#expect(NamedStar.named("VEGA") == NamedStar.named("Vega"))
		#expect(NamedStar.named("Rigil Kentaurus")?.hipparcosNumber == 71683)
	}

	@Test func unknownNamesMatchNothing() {
		#expect(NamedStar.named("") == nil)
		#expect(NamedStar.named("Vegas") == nil)
		#expect(NamedStar.named(" Vega") == nil)
		// Without a Hipparcos number
		#expect(NamedStar.named("Absolutno") == nil)
		// Not in the new reduction
		#expect(NamedStar.named("Alula Australis") == nil)
	}

	@Test func componentsUnresolvedByHipparcosShareItsAstrometry() throws {
		let izar = try #require(NamedStar.named("Izar"))
		let pulcherrima = try #require(NamedStar.named("Pulcherrima"))
		#expect(izar.hipparcosNumber == 72105)
		#expect(pulcherrima.hipparcosNumber == 72105)
		#expect(izar.star.rightAscension == pulcherrima.star.rightAscension)
		#expect(izar.brightStarNumber == 5506)
		#expect(pulcherrima.brightStarNumber == 5505)
		#expect(izar.star.radialVelocity == .kilometersPerSecond(-17))
		#expect(pulcherrima.star.radialVelocity == .kilometersPerSecond(-23))
	}

	@Test func brightStarNumbersAreMatchedAndCorrected() throws {
		// Designated by its Bayer designation, matched by place and magnitude
		#expect(NamedStar.named("Acrux")?.brightStarNumber == 4730)
		#expect(NamedStar.named("Alrescha")?.brightStarNumber == 596)
		// Two components of the Bright Star Catalogue with the same magnitude
		#expect(NamedStar.named("Diadem")?.brightStarNumber == nil)
		// The CSV's HR number is corrected
		let anunitu = try #require(NamedStar.named("Anunitu"))
		#expect(anunitu.designation == "HR 163")
		#expect(anunitu.brightStarNumber == 163)
		#expect(anunitu.hipparcosNumber == 3031)
	}
}
