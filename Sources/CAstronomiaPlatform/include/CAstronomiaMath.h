//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#ifndef CASTRONOMIAMATH_H
#define CASTRONOMIAMATH_H

#include <math.h>

#if defined(__APPLE__)
#include <vecLib/vForce.h>
#endif

#if defined(__x86_64__) && defined(__GLIBC__)
#include <immintrin.h>
#endif

// Elementary functions from the platform's C math library, for Swift's Math.

#if !defined(__APPLE__) && (defined(__GLIBC__) || defined(__ANDROID__) || defined(__linux__))
// A GNU extension, declared by <math.h> only with _GNU_SOURCE. The system module is built
// without it, so the declaration is repeated here. glibc, musl, and Bionic all provide it.
extern void sincos(double x, double *sinx, double *cosx);
#endif

/// Returns the sine of `x`, in radians.
static inline double astronomia_sin(double x)
{
	return sin(x);
}

/// Returns the cosine of `x`, in radians.
static inline double astronomia_cos(double x)
{
	return cos(x);
}

/// Returns the tangent of `x`, in radians.
static inline double astronomia_tan(double x)
{
	return tan(x);
}

/// The sine and cosine of an angle.
struct astronomia_sincos_result {
	double sin;
	double cos;
};

/// Returns the sine and cosine of `x`, in radians.
///
/// Where the platform provides `sincos` (glibc, musl, Bionic) or `__sincos` (Darwin), the two
/// share one argument reduction, which is faster than calling `sin` and `cos`; elsewhere it
/// calls both.
static inline struct astronomia_sincos_result astronomia_sincos(double x)
{
	struct astronomia_sincos_result result;
#if defined(__APPLE__)
	__sincos(x, &result.sin, &result.cos);
#elif defined(__GLIBC__) || defined(__ANDROID__) || defined(__linux__)
	sincos(x, &result.sin, &result.cos);
#else
	result.sin = sin(x);
	result.cos = cos(x);
#endif
	return result;
}

/// Returns the arcsine of `x`, in radians in the closed interval [-π/2, π/2], or NaN if `x`
/// is outside the closed interval [-1, 1].
static inline double astronomia_asin(double x)
{
	return asin(x);
}

/// Returns the arccosine of `x`, in radians in the closed interval [0, π], or NaN if `x` is
/// outside the closed interval [-1, 1].
static inline double astronomia_acos(double x)
{
	return acos(x);
}

/// Returns the arctangent of `x`, in radians in the open interval (-π/2, π/2).
static inline double astronomia_atan(double x)
{
	return atan(x);
}

/// Returns the angle of the point (`x`, `y`) from the positive x axis, in radians in the
/// closed interval [-π, π].
static inline double astronomia_atan2(double y, double x)
{
	return atan2(y, x);
}

/// Returns the natural logarithm of `x`, or NaN if `x` is negative.
static inline double astronomia_log(double x)
{
	return log(x);
}

/// Returns e raised to the power `x`.
static inline double astronomia_exp(double x)
{
	return exp(x);
}

/// Returns `x` raised to the power `y`.
static inline double astronomia_pow(double x, double y)
{
	return pow(x, y);
}

#if defined(__x86_64__) && defined(__GLIBC__)
__attribute__((target("avx2"))) __m256d _ZGVdN4v_sin(__m256d);
__attribute__((target("avx2"))) __m256d _ZGVdN4v_cos(__m256d);

__attribute__((target("avx2")))
static inline void astronomia_sincos_batch_avx2(const double *angles, double *sines, double *cosines, size_t count) {
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
static inline void astronomia_sincos_batch_avx512(const double *angles, double *sines, double *cosines, size_t count) {
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
static inline void astronomia_sincos_batch_scalar(const double *angles, double *sines, double *cosines, size_t count) {
	for (size_t j = 0; j < count; ++j) {
		const struct astronomia_sincos_result sc = astronomia_sincos(angles[j]);
		sines[j] = sc.sin;
		cosines[j] = sc.cos;
	}
}

// Computes the sines and cosines of `count` angles
static inline void astronomia_sincos_batch(const double *angles, double *sines, double *cosines, size_t count) {
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

#endif
