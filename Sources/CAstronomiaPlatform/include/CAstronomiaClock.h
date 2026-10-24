//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#ifndef CASTRONOMIACLOCK_H
#define CASTRONOMIACLOCK_H

#include <stdint.h>
#include <time.h>

// The platform's real-time clock, for Swift's Instant<UTC>.now.

/// A reading of the system's real-time clock, in POSIX time: seconds since
/// 1970-01-01T00:00:00 UTC, as if every day had 86,400 seconds.
struct astronomia_unix_time {
	/// The whole seconds since the epoch, negative before it.
	int64_t seconds;
	/// The nanoseconds past `seconds`, in the right-open interval [0, 1,000,000,000).
	int32_t nanoseconds;
};

/// Returns the system's real-time clock.
///
/// Reads `clock_gettime(CLOCK_REALTIME)`, or on Windows C11's `timespec_get(TIME_UTC)`.
static inline struct astronomia_unix_time astronomia_unix_time_now(void)
{
	struct timespec ts;
#if defined(_WIN32)
	(void)timespec_get(&ts, TIME_UTC);
#else
	(void)clock_gettime(CLOCK_REALTIME, &ts);
#endif
	const struct astronomia_unix_time result = { (int64_t)ts.tv_sec, (int32_t)ts.tv_nsec };
	return result;
}

#endif
