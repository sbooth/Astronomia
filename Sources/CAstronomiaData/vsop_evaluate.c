//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#include "CAstronomiaData.h"
#include "CAstronomiaMath.h"

// The number of terms whose sines and cosines are computed at once
#define VSOP_CHUNK_SIZE 128

double astronomia_vsop_evaluate_series(const struct astronomia_vsop_term *terms, size_t count, double t, double time_power, double initial_sum) {
	double phases[VSOP_CHUNK_SIZE];
	double sines[VSOP_CHUNK_SIZE];
	double cosines[VSOP_CHUNK_SIZE];

	double sum = initial_sum;

	for (size_t offset = 0; offset < count; ) {
		size_t n = count - offset;
		if (n > VSOP_CHUNK_SIZE) { n = VSOP_CHUNK_SIZE; }

		// Build a contiguous batch of angles
		for (size_t j = 0; j < n; ++j) {
			const struct astronomia_vsop_term *term = &terms[offset + j];
			phases[j] = term->phase + term->frequency * t;
		}

		astronomia_sincos_batch(phases, sines, cosines, n);

		// Add the terms in their order
		for (size_t j = 0; j < n; ++j) {
			const struct astronomia_vsop_term *term = &terms[offset + j];
			sum = sum + time_power * (term->s * sines[j] + term->c * cosines[j]);
		}

		offset += n;
	}

	return sum;
}
