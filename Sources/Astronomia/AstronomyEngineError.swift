//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import CAstronomyEngine

/// An error from Astronomy Engine.
struct AstronomyEngineError: Error {
	/// The underlying error code from Astronomy Engine.
	let status: astro_status_t
}
