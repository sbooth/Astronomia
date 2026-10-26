//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaData

/// A star with a name approved by the International Astronomical Union, and its astrometry.
///
/// The built-in named stars, ``all``, are those of the IAU Catalog of Star Names, of the IAU
/// Working Group on Star Names (WGSN), that are in Hipparcos, the New Reduction (van Leeuwen
/// 2007): nearly every named star visible to the eye, and some fainter ones, many of them hosts
/// of exoplanets. A named star without a Hipparcos number, as many faint hosts of exoplanets,
/// or not in the new reduction, as Alula Australis, isn't included.
///
/// Each star's ``star`` has the astrometry of the new reduction: its place in the ICRS at epoch
/// J1991.25, its proper motion, and its parallax, or none if the parallax isn't positive. Its
/// radial velocity is that of the Bright Star Catalogue, 5th Revised Ed. (Hoffleit and Warren
/// 1991), in whole kilometers per second, or 0 if the star isn't in that catalog or has no
/// radial velocity there. The accelerations of the new reduction's 7- and 9-parameter
/// solutions, for some double stars, are left out.
///
/// ```swift
/// if let vega = NamedStar.named("Vega") {
/// 	let place = try Observer.geocenter.observation(at: instant).apparentPlace(of: vega.star)
/// 	let events = try site.riseTransitSetEvents(of: vega.star, from: start, to: end)
/// }
/// let orion = NamedStar.all.filter { $0.constellation == "Ori" }
/// ```
public struct NamedStar: Hashable, Sendable {
	/// The name, as the IAU spells it, with its diacritics.
	public let name: String
	/// The designation of the IAU Catalog of Star Names, as `HR 7001`, `HD 130322`, or
	/// `GJ 699`.
	public let designation: String
	/// The Bayer, Flamsteed, or variable star designation, as `α Lyr`, `20 Cet`, or
	/// `V2500 Oph`, or `nil` if the catalog gives none.
	public let bayerDesignation: String?
	/// The IAU's three-letter abbreviation of the constellation, as `Lyr`.
	public let constellation: String
	/// The number in the Hipparcos catalog.
	///
	/// The components of a double star unresolved by Hipparcos, as Izar and Pulcherrima, have
	/// the same number and astrometry.
	public let hipparcosNumber: Int
	/// The number in the Bright Star Catalogue (the HR number), or `nil` if the star isn't in
	/// that catalog or can't be told from another component of a double star there.
	public let brightStarNumber: Int?
	/// The Hipparcos magnitude, Hp, of the new reduction.
	public let hipparcosMagnitude: Double
	/// The star's catalog astrometry.
	public let star: Star

	/// The name without its diacritics, for lookups.
	let asciiName: String

	/// The built-in named stars, in order of their names, compared without diacritics or case.
	///
	/// The stars are read from the built-in data as they are accessed, and aren't kept.
	public static let all = Catalog()

	/// The built-in named stars, read from the built-in data as they are accessed.
	///
	/// The collection holds no stars of its own: each is made from the built-in data when it is
	/// accessed, so iterating over the stars or filtering them uses no more memory than the
	/// stars kept.
	public struct Catalog: RandomAccessCollection, Sendable {
		/// Creates the collection of the built-in named stars.
		init() {}

		/// The built-in data.
		private var entries: UnsafeBufferPointer<astronomia_named_star> {
			let data = astronomia_named_stars
			return UnsafeBufferPointer(start: data.stars, count: data.count)
		}

		/// The position of the first star, 0.
		public var startIndex: Int { 0 }

		/// The position after the last star, the number of stars.
		public var endIndex: Int { astronomia_named_stars.count }

		/// The star at a position.
		///
		/// - Precondition: The position is in the half-open interval [0, ``endIndex``).
		public subscript(position: Int) -> NamedStar {
			NamedStar(entries[position])
		}
	}

	/// The positions of the stars in ``all`` by their names and their names without
	/// diacritics, lowercased.
	private static let indexes: [String: Int] = {
		var indexes: [String: Int] = [:]
		let data = astronomia_named_stars
		for (index, entry) in UnsafeBufferPointer(start: data.stars, count: data.count).enumerated() {
			indexes[String(cString: entry.name).lowercased()] = index
			indexes[String(cString: entry.ascii_name).lowercased()] = index
		}
		return indexes
	}()

	/// Returns the built-in named star with a name.
	///
	/// The name is matched without case, with or without its diacritics, so `"Mönch"`,
	/// `"monch"`, and `"MONCH"` are the same star.
	///
	/// - Parameter name: The name.
	/// - Returns: The star, or `nil` if no built-in star has the name.
	public static func named(_ name: String) -> NamedStar? {
		indexes[name.lowercased()].map { all[$0] }
	}

	/// The epoch of Hipparcos, J1991.25, JD 2448349.0625 TDB.
	static let hipparcosEpoch = Instant<TDB>(JulianDate(uncheckedJulianDayNumber: 2_448_349, fractionFromNoon: 0.0625))

	/// Creates a named star from its entry in the built-in data.
	init(_ entry: astronomia_named_star) {
		name = String(cString: entry.name)
		asciiName = String(cString: entry.ascii_name)
		designation = String(cString: entry.designation)
		let bayer = String(cString: entry.bayer_designation)
		bayerDesignation = bayer.isEmpty ? nil : bayer
		constellation = String(cString: entry.constellation)
		hipparcosNumber = Int(entry.hip)
		brightStarNumber = entry.hr > 0 ? Int(entry.hr) : nil
		hipparcosMagnitude = entry.hipparcos_magnitude
		star = Star(
			uncheckedRightAscension: Angle(radians: entry.right_ascension),
			declination: Angle(radians: entry.declination),
			properMotionInRightAscension: Angle(milliarcseconds: entry.proper_motion_ra),
			properMotionInDeclination: Angle(milliarcseconds: entry.proper_motion_dec),
			parallax: entry.parallax > 0 ? Angle(milliarcseconds: entry.parallax) : nil,
			radialVelocity: Speed(kilometersPerSecond: entry.radial_velocity),
			epoch: Self.hipparcosEpoch)
	}
}
