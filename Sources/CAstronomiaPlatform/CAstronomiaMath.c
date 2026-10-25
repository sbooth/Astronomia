//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#include "CAstronomiaMath.h"

#if defined(__APPLE__)
#include <vecLib/vForce.h>
#endif

#if defined(__x86_64__) && defined(__GLIBC__)
#include <immintrin.h>
#endif

#if defined(__x86_64__) && defined(__GLIBC__)
__attribute__((target("avx2"))) __m256d _ZGVdN4v_sin(__m256d);
__attribute__((target("avx2"))) __m256d _ZGVdN4v_cos(__m256d);

__attribute__((target("avx2")))
static void astronomia_sincos_batch_avx2(const double *angles, double *sines, double *cosines, size_t count) {
	size_t j = 0;
	for (; j + 4 <= count; j += 4) {
		__m256d x = _mm256_loadu_pd(angles + j);
		_mm256_storeu_pd(sines + j, _ZGVdN4v_sin(x));
		_mm256_storeu_pd(cosines + j, _ZGVdN4v_cos(x));
	}
	for (; j < count; ++j) { sines[j] = sin(angles[j]); cosines[j] = cos(angles[j]); }
}

__attribute__((target("avx512f"))) __m512d _ZGVeN8v_sin(__m512d);
__attribute__((target("avx512f"))) __m512d _ZGVeN8v_cos(__m512d);

__attribute__((target("avx512f")))
static void astronomia_sincos_batch_avx512(const double *angles, double *sines, double *cosines, size_t count) {
	size_t j = 0;
	for (; j + 8 <= count; j += 8) {
		__m512d x = _mm512_loadu_pd(angles + j);
		_mm512_storeu_pd(sines + j, _ZGVeN8v_sin(x));
		_mm512_storeu_pd(cosines + j, _ZGVeN8v_cos(x));
	}
	if (j < count) {
		// Masked tail: load the remaining 1-7 lanes, zero-filling the rest
		const __mmask8 m = (__mmask8)((1u << (count - j)) - 1);
		__m512d x = _mm512_maskz_loadu_pd(m, angles + j);
		_mm512_mask_storeu_pd(sines + j, m, _ZGVeN8v_sin(x));
		_mm512_mask_storeu_pd(cosines + j, m, _ZGVeN8v_cos(x));
	}
}
#endif

// Portable scalar fallback
static void astronomia_sincos_batch_scalar(const double *angles, double *sines, double *cosines, size_t count) {
	for (size_t j = 0; j < count; ++j) {
		const struct astronomia_sincos_result sc = astronomia_sincos(angles[j]);
		sines[j] = sc.sin;
		cosines[j] = sc.cos;
	}
}

// Computes the sines and cosines of `count` angles
void astronomia_sincos_batch(const double *angles, double *sines, double *cosines, size_t count) {
#if defined(__APPLE__)
	const int n = (int)count;
	vvsincos(sines, cosines, angles, &n);
#elif defined(__x86_64__) && defined(__GLIBC__)
	if (__builtin_cpu_supports("avx512f")) {
		astronomia_sincos_batch_avx512(angles, sines, cosines, count);
	} else if (__builtin_cpu_supports("avx2")) {
		astronomia_sincos_batch_avx2(angles, sines, cosines, count);
	} else {
		astronomia_sincos_batch_scalar(angles, sines, cosines, count);
	}
#else
	astronomia_sincos_batch_scalar(angles, sines, cosines, count);
#endif
}
