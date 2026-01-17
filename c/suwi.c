/* =============================================================================
 * SUWI Lightweight Block Cipher (128-bit block / 128-bit key) - Reference C Code
 * =============================================================================
 *
 * Purpose
 * -------
 * This file provides a portable reference implementation of the SUWI block
 * cipher as specified in the manuscript:
 *   "SUWI: A Unified 128-bit Lightweight Block Cipher with Consistent Efficiency
 *    Across FPGA, ASIC, and Embedded Platforms", IEEE Access, 2026.
 *
 * This implementation prioritizes clarity and bit-exact reproducibility across
 * platforms (MCU/PC) rather than micro-architectural optimization.
 *
 * Algorithm Summary
 * -----------------
 * - Block size : 128 bits (two 64-bit halves, Feistel structure)
 * - Key size   : 128 bits
 * - Rounds     : 32
 * - Round core : AND, XOR, fixed rotations {2, 7, 11}; no S-box; no addition
 * - Key sched  : On-the-fly 64-bit LFSR-derived round keys (no expanded key RAM)
 * - Final swap : Omitted; ciphertext is output as (L32 || R32)
 *
 * Constants (as in the paper)
 * ---------------------------
 * - CF (round constant): 0x9e3779b97f4a7c15
 * - CK (key-mixing const): 0xb5c0fbcfec4d3b2f
 *
 * Reproducibility Notes
 * ---------------------
 * - The code is intended to be functionally equivalent to the specification
 *   (bit-exact ciphertext for a given plaintext/key).
 * - Timing, energy, and side-channel characteristics depend on compiler, target,
 *   and micro-architectural details and are outside the scope of this reference.
 *
 * Repository
 * ----------
 * Release tag : v1.0-paper
 * 
 * License
 * -------
 * MIT License (see LICENSE file in repository).
 *
 * Contact
 * -------
 * W. A. Susantha Wijesinghe, Wayamba University of Sri Lanka
 * Email: susantha@wyb.ac.lk
 * =============================================================================
 */


#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdbool.h>

#define ROUNDS 32
#define MASK_64 ((uint64_t)(~0ULL))

// Constants 
const uint64_t CONSTANT_F = 0x9e3779b97f4a7c15ULL;
const uint64_t CONSTANT_K = 0xb5c0fbcfec4d3b2fULL;

// Rotate left for 64-bit
static inline uint64_t rotl64(uint64_t x, unsigned int r) {
    return (x << r) | (x >> (64 - r));
}

static inline uint64_t f_func(uint64_t x) {
    uint64_t t1 = rotl64(x, 2);
    uint64_t t2 = rotl64(x, 7);
    uint64_t t3 = rotl64(x, 11);
    return (t1 & t2) ^ t3 ^ CONSTANT_F;
}

static inline uint64_t lfsr_advance(uint64_t state) {
    // taps at positions 63,61,56,31,28,23,0 (zero-based from LSB)
    uint64_t feedback = ((state >> 63) ^ (state >> 61) ^ (state >> 56) ^
                         (state >> 31) ^ (state >> 28) ^ (state >> 23) ^
                         (state >> 0)) & 1ULL;
    return ((state << 1) & MASK_64) | feedback;
}

void generate_rk_list(uint64_t rk[ROUNDS], __uint128_t key) {
    uint64_t key_high = (uint64_t)(key >> 64);
    uint64_t key_low  = (uint64_t)(key & MASK_64);
    uint64_t lfsr_state = key_high != 0 ? key_high : 1ULL;
    for (int i = 0; i < ROUNDS; i++) {
        rk[i] = key_low ^ lfsr_state ^ CONSTANT_K;
        lfsr_state = lfsr_advance(lfsr_state);
    }
}

__uint128_t encrypt(__uint128_t plaintext, __uint128_t key) {
    uint64_t rk[ROUNDS];
    generate_rk_list(rk, key);
    uint64_t left  = (uint64_t)(plaintext >> 64);
    uint64_t right = (uint64_t)(plaintext & MASK_64);
    for (int i = 0; i < ROUNDS; i++) {
        uint64_t temp = right ^ f_func(left) ^ rk[i];
        right = left;
        left  = temp;
    }
    __uint128_t result = ((__uint128_t)left << 64) | right;
    return result;
}

__uint128_t decrypt(__uint128_t ciphertext, __uint128_t key) {
    uint64_t rk[ROUNDS];
    generate_rk_list(rk, key);
    uint64_t left  = (uint64_t)(ciphertext >> 64);
    uint64_t right = (uint64_t)(ciphertext & MASK_64);
    for (int i = ROUNDS - 1; i >= 0; i--) {
        uint64_t temp = right;
        right = left ^ f_func(right) ^ rk[i];
        left  = temp;
    }
    __uint128_t result = ((__uint128_t)left << 64) | right;
    return result;
}

// Print 128-bit value as zero-padded 32-hex-digit string
void print_u128_hex(__uint128_t x) {
    uint64_t hi = (uint64_t)(x >> 64);
    uint64_t lo = (uint64_t)(x & MASK_64);
    printf("%016" PRIx64 "%016" PRIx64, hi, lo);
}

void run_test(__uint128_t plaintext, __uint128_t key) {
    __uint128_t ciphertext = encrypt(plaintext, key);
    __uint128_t decrypted  = decrypt(ciphertext, key);
    printf("Plaintext : ");
    print_u128_hex(plaintext);
    printf("\n");
    printf("Key       : ");
    print_u128_hex(key);
    printf("\n");
    printf("Ciphertext: ");
    print_u128_hex(ciphertext);
    printf("\n");
    printf("Decrypted : ");
    print_u128_hex(decrypted);
    printf("\n");
    printf("Correct   : %s\n\n", decrypted == plaintext ? "true" : "false");
}


int main(void) {
    printf("Running SUWI Test Vectors...\n\n");
    // Test 1: All-zero (LFSR seeded to 1)
    run_test((__uint128_t)0x0000000000000000ULL << 64 | (__uint128_t)0x0000000000000000ULL,
             (__uint128_t)0x0000000000000000ULL << 64 | (__uint128_t)0x0000000000000000ULL);

    // Test 2: All-ones
    run_test((__uint128_t)0xffffffffffffffffULL << 64 | (__uint128_t)0xffffffffffffffffULL,
             (__uint128_t)0xffffffffffffffffULL << 64 | (__uint128_t)0xffffffffffffffffULL);

    // Test 3: Alternating bits
    run_test((__uint128_t)0x5555555555555555ULL << 64 | (__uint128_t)0x5555555555555555ULL,
             (__uint128_t)0xaaaaaaaaaaaaaaaaULL << 64 | (__uint128_t)0xaaaaaaaaaaaaaaaaULL);

    // Test 4: Random pair 1
    run_test((__uint128_t)0x0123456789abcdefULL << 64 | (__uint128_t)0x0123456789abcdefULL,
             (__uint128_t)0xfedcba9876543210ULL << 64 | (__uint128_t)0xfedcba9876543210ULL);

    // Test 5: Random pair 2
    run_test((__uint128_t)0xa1b2c3d4e5f60718ULL << 64 | (__uint128_t)0xa1b2c3d4e5f60718ULL,
             (__uint128_t)0x192a3b4c5d6e7f80ULL << 64 | (__uint128_t)0x192a3b4c5d6e7f80ULL);

    // Test 6: Edge case
    run_test((__uint128_t)0x8000000000000000ULL << 64 | (__uint128_t)0x0000000000000001ULL,
             (__uint128_t)0x7fffffffffffffffULL << 64 | (__uint128_t)0xffffffffffffffffULL);

    printf("All tests completed.\n");
    return 0;
}

