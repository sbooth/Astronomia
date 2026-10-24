//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#include <stddef.h>
#include <stdint.h>

#include <CAstronomiaData.h>
#include <CAstronomiaMath.h>

#if defined(__APPLE__)
#include <vecLib/vForce.h>
#endif

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

#if defined(__APPLE__)
		// Evaluate the batch of sine and cosine values
		int vector_count = (int)n;
		vvsincos(sines, cosines, phases, &vector_count);
#else
		// Portable scalar fallback
		for (size_t j = 0; j < n; ++j) {
			struct astronomia_sincos_result sc = astronomia_sincos(phases[j]);
			sines[j] = sc.sin;
			cosines[j] = sc.cos;
		}
#endif

		// Add the terms in their order
		for (size_t j = 0; j < n; ++j) {
			const struct astronomia_vsop_term *term = &terms[offset + j];
			sum = sum + time_power * (term->s * sines[j] + term->c * cosines[j]);
		}

		offset += n;
	}

	return sum;
}
