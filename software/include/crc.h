#ifndef _UTIL_CRC_H
#define _UTIL_CRC_H

#include <stdint.h>
#include <stddef.h>

#define CRC_POLY_CRC32 0x4c11db7u
#define CRC_POLY_CRC16_CCITT (0x1021u << 16)

// Regular old bit reverse functions
static inline uint32_t crc_bitrev_u32(uint32_t x) {
	uint32_t mask = ~0u;
	for (int shift = 16; shift >= 1; shift >>= 1) {
		mask ^= mask >> shift;
		x = (x & mask) >> shift | (x & ~mask) << shift;
	}
	return x;
}

static inline uint8_t crc_bitrev_u8(uint8_t x) {
	uint8_t mask = 0xffu;
	for (int shift = 4; shift >= 1; shift >>= 1) {
		mask ^= mask >> shift;
		x = (x & mask) >> shift | (x & ~mask) << shift;
	}
	return x;
}

// For calculating streaming checksums. Each input byte is reversed. Note you
// must perform the final XOR and bitrev yourself if using this.
static inline uint32_t crc_checksum_byte(uint32_t poly, uint32_t accum, uint8_t src) {
	uint32_t byte_xord = (crc_bitrev_u8(src) << 24) ^ (accum & 0xff000000u);
	for (int bit = 0; bit < 8; ++bit) {
		if ((int32_t)byte_xord < 0) {
			byte_xord <<= 1;
			byte_xord ^= poly;
		}
		else {
			byte_xord <<= 1;
		}
	}
	return (accum << 8) ^ byte_xord;
}

// Invoke the above on a buffer, and perform final output reflection and
// invert all bits (standard CRC-32 parameters)
static inline uint32_t crc_checksum_buf(uint32_t poly, uint32_t seed, const uint8_t *src, int len) {
	uint32_t accum = seed;
	for (int i = 0; i < len; ++i)
		accum = crc_checksum_byte(poly, accum, src[i]);
	return ~crc_bitrev_u32(accum);
}

#endif
