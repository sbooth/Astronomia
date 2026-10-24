
//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//

#include "CAstronomiaData.h"
#include "CAstronomiaMath.h"

#if defined(__APPLE__)
#include <vecLib/vForce.h>
#endif

// The number of terms whose sines and cosines are computed at once
#define IAU_CHUNK_SIZE 128

double astronomia_iau_evaluate_series(const struct astronomia_iau_series *series, size_t series_count, const struct astronomia_iau_term *terms, size_t term_count, const double arguments[14], double t, int32_t level)
{
	if (series == NULL || terms == NULL || arguments == NULL || level < 0 || level >= ASTRONOMIA_PRECISION_LEVELS) {
		return NAN;
	}

	double total = 0.0;
	size_t end = term_count;

	for (size_t si = series_count; si > 0; --si) {
		const struct astronomia_iau_series *header = &series[si - 1];

		const size_t full_count = (size_t)header->counts[0];

		// Invalid generated data
		if (full_count > end) { return NAN; }

		const size_t start = end - full_count;
		const size_t selected_count = (size_t)header->counts[level];

		if (selected_count > full_count) { return NAN; }

		double sum = 0.0;

		for(size_t current_end = start + selected_count; current_end > start; ) {
			size_t n = current_end - start;
			if (n > IAU_CHUNK_SIZE) { n = IAU_CHUNK_SIZE; }

			double angles[IAU_CHUNK_SIZE];
			double sines[IAU_CHUNK_SIZE];
			double cosines[IAU_CHUNK_SIZE];

			// Construct the angles in descending term-index order
			for (size_t j = 0; j < n; ++j) {
				const struct astronomia_iau_term *term = &terms[current_end - 1 - j];
				const int8_t *m = term->multipliers;
				const double *a = arguments;

				double argument = (double)m[0] * a[0] + (double)m[1] * a[1] + (double)m[2] * a[2] + (double)m[3] * a[3];
				argument = argument + (double)m[4] * a[4] + (double)m[5] * a[5] + (double)m[6] * a[6] + (double)m[7] * a[7];
				argument = argument + (double)m[8] * a[8] + (double)m[9] * a[9] + (double)m[10] * a[10] + (double)m[11] * a[11];
				argument = argument + (double)m[12] * a[12] + (double)m[13] * a[13];

				angles[j] = argument;
			}

#if defined(__APPLE__)
			// Evaluate the batch of sine and cosine values
			const int vector_count = (int)n;
			vvsincos(sines, cosines, angles, &vector_count);
#else
			// Portable scalar fallback
			for (size_t j = 0; j < n; ++j) {
				const struct astronomia_sincos_result sc = astronomia_sincos(angles[j]);
				sines[j] = sc.sin;
				cosines[j] = sc.cos;
			}
#endif

			for (size_t j = 0; j < n; ++j) {
				const struct astronomia_iau_term *term = &terms[current_end - 1 - j];
				sum = sum + (term->s * sines[j] + term->c * cosines[j]);
			}

			current_end -= n;
		}

		const double power = astronomia_pow(t, header->power);
		total = total + sum * power;

		// Advance over the complete series, not just its prefix
		end = start;
	}

	return total;
}
