//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#ifndef CASTRONOMIACLOCK_H
#define CASTRONOMIACLOCK_H

#include <stdbool.h>
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

/// Reads the system's real-time clock.
///
/// Reads `clock_gettime(CLOCK_REALTIME)`, or on Windows C11's `timespec_get(TIME_UTC)`.
///
/// - Parameter time: The reading, set only if the clock is read.
/// - Returns: `true` if the clock is read, or `false` if the platform reports a failure.
static inline bool astronomia_unix_time_now(struct astronomia_unix_time *time)
{
	struct timespec ts;
#if defined(_WIN32)
	if (timespec_get(&ts, TIME_UTC) != TIME_UTC) { return false; }
#else
	if (clock_gettime(CLOCK_REALTIME, &ts) != 0) { return false; }
#endif
	time->seconds = (int64_t)ts.tv_sec;
	time->nanoseconds = (int32_t)ts.tv_nsec;
	return true;
}

#endif
