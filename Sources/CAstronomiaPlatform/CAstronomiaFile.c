//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#include "CAstronomiaFile.h"

#include <errno.h>
#include <stdint.h>

#if defined(__unix__) || defined(__APPLE__)
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

int astronomia_map_file(const char *path, struct astronomia_mapped_file *file) {
	int fd;
	do {
		fd = open(path, O_RDONLY | O_CLOEXEC);
	} while (fd < 0 && errno == EINTR);
	if (fd < 0) {
		return errno;
	}
	struct stat status;
	if (fstat(fd, &status) != 0) {
		const int error = errno;
		close(fd);
		return error;
	}
	if (S_ISDIR(status.st_mode)) {
		close(fd);
		return EISDIR;
	}
	if (status.st_size < 0 || (uintmax_t)status.st_size > (uintmax_t)SIZE_MAX) {
		close(fd);
		return EFBIG;
	}
	const size_t size = (size_t)status.st_size;
	if (size == 0) {
		// mmap rejects an empty mapping.
		close(fd);
		file->bytes = NULL;
		file->size = 0;
		return 0;
	}
	void *bytes = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
	const int error = errno;
	// The mapping keeps the file open.
	close(fd);
	if (bytes == MAP_FAILED) {
		return error;
	}
	file->bytes = bytes;
	file->size = size;
	return 0;
}

void astronomia_unmap_file(struct astronomia_mapped_file file) {
	if (file.bytes != NULL) {
		munmap((void *)file.bytes, file.size);
	}
}

#else

int astronomia_map_file(const char *path, struct astronomia_mapped_file *file) {
	(void)path;
	(void)file;
	return ENOSYS;
}

void astronomia_unmap_file(struct astronomia_mapped_file file) {
	(void)file;
}

#endif
