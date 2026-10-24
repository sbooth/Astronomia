//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#include "CAstronomiaData.h"
#include "CAstronomiaMath.h"

#if defined(__APPLE__)
#include <vecLib/vForce.h>
#endif

// The number of terms whose sines and cosines are computed at once
#define ELP_CHUNK_SIZE 128

// Computes the sines and cosines of `count` angles, with vForce on Apple platforms
static void elp_sincos_batch(const double *phases, double *sines, double *cosines, size_t count) {
#if defined(__APPLE__)
	const int n = (int)count;
	vvsincos(sines, cosines, phases, &n);
#else
	for (size_t j = 0; j < count; ++j) {
		struct astronomia_sincos_result sc = astronomia_sincos(phases[j]);
		sines[j] = sc.sin;
		cosines[j] = sc.cos;
	}
#endif
}

struct astronomia_elp_sum_rate astronomia_elp_main_evaluate(const struct astronomia_elp_main_term *terms, const double *amplitudes, size_t count, const double *x, const double *xp, int is_distance, double initial_sum, double initial_rate) {
	double phases[ELP_CHUNK_SIZE];
	double angle_rates[ELP_CHUNK_SIZE];
	double sines[ELP_CHUNK_SIZE];
	double cosines[ELP_CHUNK_SIZE];

	struct astronomia_elp_sum_rate result = {
		.sum = initial_sum,
		.rate = initial_rate
	};

	for (size_t offset = 0; offset < count; ) {
		size_t n = count - offset;
		if (n > ELP_CHUNK_SIZE) { n = ELP_CHUNK_SIZE; }

		// The angles of the terms and their rates
		for (size_t j = 0; j < n; ++j) {
			const struct astronomia_elp_main_term *term = &terms[offset + j];

			const double i0 = (double)term->multipliers[0];
			const double i1 = (double)term->multipliers[1];
			const double i2 = (double)term->multipliers[2];
			const double i3 = (double)term->multipliers[3];

			phases[j] =
				i0 * x[0] + i1 * x[1] +
				i2 * x[2] + i3 * x[3];

			angle_rates[j] =
				i0 * xp[0] + i1 * xp[1] +
				i2 * xp[2] + i3 * xp[3];
		}

		elp_sincos_batch(phases, sines, cosines, n);

		// Add the terms in their order
		for (size_t j = 0; j < n; ++j) {
			const double a = amplitudes[offset + j];
			const double s = sines[j];
			const double c = cosines[j];
			const double yp = angle_rates[j];

			if (is_distance) {
				result.sum = result.sum + a * c;
				result.rate = result.rate - a * yp * s;
			} else {
				result.sum = result.sum + a * s;
				result.rate = result.rate + a * yp * c;
			}
		}

		offset += n;
	}

	return result;
}

struct astronomia_elp_sum_rate astronomia_elp_perturbation_evaluate(const struct astronomia_elp_perturbation_term *terms, size_t count, const double *x, const double *xp, double t_power, double t_power_rate, double initial_sum, double initial_rate) {
	double phases[ELP_CHUNK_SIZE];
	double angle_rates[ELP_CHUNK_SIZE];
	double sines[ELP_CHUNK_SIZE];
	double cosines[ELP_CHUNK_SIZE];

	struct astronomia_elp_sum_rate result = {
		.sum = initial_sum,
		.rate = initial_rate
	};

	for (size_t offset = 0; offset < count; ) {
		size_t n = count - offset;
		if (n > ELP_CHUNK_SIZE) { n = ELP_CHUNK_SIZE; }

		// The angles of the terms and their rates
		for (size_t j = 0; j < n; ++j) {
			const struct astronomia_elp_perturbation_term *term = &terms[offset + j];

			double y = 0.0;
			double yp = 0.0;

			for (size_t k = 0; k < 13; ++k) {
				const double multiplier = (double)term->multipliers[k];
				y = y + multiplier * x[k];
				yp = yp + multiplier * xp[k];
			}

			phases[j] = y;
			angle_rates[j] = yp;
		}

		elp_sincos_batch(phases, sines, cosines, n);

		// Add the terms in their order
		for (size_t j = 0; j < n; ++j) {
			const struct astronomia_elp_perturbation_term *term = &terms[offset + j];

			const double s = sines[j];
			const double c = cosines[j];
			const double yp = angle_rates[j];

			const double value = term->s * s + term->c * c;

			result.sum = result.sum + t_power * value;
			result.rate = result.rate + t_power_rate * value + t_power * yp * (term->s * c - term->c * s);
		}

		offset += n;
	}

	return result;
}
