
# ==============================================================================
# SUWI Lightweight Block Cipher (128-bit block / 128-bit key) - Reference Python
# ==============================================================================
#
# Purpose
# -------
# This module provides a readable, bit-exact reference implementation of the
# SUWI block cipher as specified in the manuscript:
#   "SUWI: A Unified 128-bit Lightweight Block Cipher with Consistent Efficiency
#    Across FPGA, ASIC, and Embedded Platforms", IEEE Access, 2026.
#
# The implementation is intended for:
# - algorithm validation,
# - test vector generation and verification,
# - reproducibility of functional behavior across platforms.
#
# Algorithm Summary
# -----------------
# - Block size : 128 bits (Feistel, two 64-bit halves)
# - Key size   : 128 bits
# - Rounds     : 32
# - Round core : AND, XOR, fixed rotations {2, 7, 11}; no S-box; no addition
# - Key sched  : On-the-fly 64-bit LFSR-derived round keys
# - Final swap : Omitted; ciphertext is (L32 || R32)
#
# Constants (as in the paper)
# ---------------------------
# - CF (round constant): 0x9e3779b97f4a7c15
# - CK (key-mixing const): 0xb5c0fbcfec4d3b2f
#
# Reproducibility Notes
# ---------------------
# - This code aims for bit-accurate results, not speed.
# - Performance depends on Python interpreter version and host system.
#
# Repository
# ----------
# Release tag : v1.0-paper
#
# License
# -------
# MIT License (see LICENSE file in repository).
#
# Contact
# -------
# W. A. Susantha Wijesinghe, Wayamba University of Sri Lanka
# Email: susantha@wyb.ac.lk
# ==============================================================================


MASK_64 = (1 << 64) - 1  
LFSR_TAPS = [0, 23, 28, 31, 56, 61, 63]  
CONSTANT_F = 0x9e3779b97f4a7c15  
CONSTANT_K = 0xb5c0fbcfec4d3b2f  

def rot_left(x, r, mask=MASK_64):
    """Left rotation of x by r bits, masked to 64 bits."""
    return ((x << r) & mask) | (x >> (64 - r))

def f(x):
    """SUWI round function: (ROT(x,2) & ROT(x,7)) ^ ROT(x,11) ^ CONSTANT_F"""
    return (rot_left(x, 2) & rot_left(x, 7)) ^ rot_left(x, 11) ^ CONSTANT_F

def lfsr_advance(state, taps=LFSR_TAPS, mask=MASK_64):
    """Advance 64-bit Fibonacci LFSR by one bit (left shift)."""
    lsb = 0
    for tap in taps:
        lsb ^= (state >> tap) & 1
    return ((state << 1) & mask) | lsb

def generate_rk_list(key, rounds=32, mask=MASK_64):
    """Generate list of 64-bit round keys using LFSR."""
    key_high = (key >> 64) & mask
    key_low = key & mask
    lfsr_state = key_high if key_high != 0 else 1  # Seed to 1 if zero to avoid fixed point
    rk_list = []
    for _ in range(rounds):
        rk = key_low ^ lfsr_state ^ CONSTANT_K
        rk_list.append(rk)
        lfsr_state = lfsr_advance(lfsr_state)
    return rk_list

def encrypt(plaintext, key, rounds=32, mask=MASK_64):
    """Encrypt 128-bit plaintext with 128-bit key."""
    rk_list = generate_rk_list(key, rounds, mask)
    left = (plaintext >> 64) & mask
    right = plaintext & mask
    for i in range(rounds):
        temp = right ^ f(left) ^ rk_list[i]
        right = left
        left = temp
    return (left << 64) | right

def decrypt(ciphertext, key, rounds=32, mask=MASK_64):
    """Decrypt 128-bit ciphertext with 128-bit key."""
    rk_list = generate_rk_list(key, rounds, mask)
    left = (ciphertext >> 64) & mask
    right = ciphertext & mask
    for i in range(rounds - 1, -1, -1):
        temp = right
        right = left ^ f(right) ^ rk_list[i]
        left = temp
    return (left << 64) | right

def run_test(plaintext, key):
    ciphertext = encrypt(plaintext, key)
    decrypted = decrypt(ciphertext, key)
    print(f"Plaintext: {plaintext:032x}")
    print(f"Key: {key:032x}")
    print(f"Ciphertext: {ciphertext:032x}")
    print(f"Decrypted: {decrypted:032x}")
    print(f"Correct: {decrypted == plaintext}\n")

if __name__ == "__main__":
    print("Running SUWI Test Vectors...\n")
    
    # Test 1: All-zero (note: LFSR seeded to 1)
    run_test(0x00000000000000000000000000000000, 0x00000000000000000000000000000000)
    
    # Test 2: All-ones
    run_test(0xffffffffffffffffffffffffffffffff, 0xffffffffffffffffffffffffffffffff)
    
    # Test 3: Alternating bits (0x5555... and 0xaaaa...)
    run_test(0x55555555555555555555555555555555, 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
    
    # Test 4: Random pair 1
    run_test(0x0123456789abcdef0123456789abcdef, 0xfedcba9876543210fedcba9876543210)
    
    # Test 5: Random pair 2
    run_test(0xa1b2c3d4e5f60718a1b2c3d4e5f60718, 0x192a3b4c5d6e7f80192a3b4c5d6e7f80)
    
    # Test 6: Random pair 3 (edge case with high bits)
    run_test(0x80000000000000000000000000000001, 0x7fffffffffffffffffffffffffffffff)
    
    print("All tests completed.")




