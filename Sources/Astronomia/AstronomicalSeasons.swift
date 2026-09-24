//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import CAstronomyEngine

/// The equinoxes and solstices defining the astronomical seasons.
public struct AstronomicalSeasons {
	/// The March, or northward, equinox.
	///
	/// The March equinox is known as the vernal equinox (spring equinox) in the Northern Hemisphere and as the autumnal equinox in the Southern Hemisphere.
	public let marchEquinox: Date
	/// The June, or northern, solstice.
	///
	/// The June solstice is known as the summer solstice in the Northern Hemisphere and as the winter solstice in the Southern Hemisphere.
	public let juneSolstice: Date
	/// The September, or southward, equinox.
	///
	/// The September equinox is known as the autumnal equinox in the Northern Hemisphere and as the vernal equinox (spring equinox) in the Southern Hemisphere.
	public let septemberEquinox: Date
	/// The December, or southern, solstice.
	///
	/// The December solstice is known as the winter solstice in the Northern Hemisphere and as the summer solstice in the Southern Hemisphere.
	public let decemberSolstice: Date
}

extension AstronomicalSeasons {
	/// Calculates and initializes the astronomical seasons for `year`.
	/// - note: Years from 1800 to 2100 are supported.
	public init(year: Int) throws {
		precondition(year >= 1800)
		precondition(year <= 2100)

		let seasons = Astronomy_Seasons(Int32(year))
		guard seasons.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: seasons.status)
		}

		marchEquinox = seasons.mar_equinox.toDate()
		juneSolstice = seasons.jun_solstice.toDate()
		septemberEquinox = seasons.sep_equinox.toDate()
		decemberSolstice = seasons.dec_solstice.toDate()
	}
}
