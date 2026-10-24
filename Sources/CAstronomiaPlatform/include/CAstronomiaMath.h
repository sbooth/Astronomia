//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#ifndef CASTRONOMIAMATH_H
#define CASTRONOMIAMATH_H

#include <math.h>

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

#endif
