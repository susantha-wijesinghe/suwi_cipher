# SUWI: A Unified 128-bit Lightweight Block Cipher

This repository provides **reference implementations and evaluation artifacts** for **SUWI**, a 128-bit lightweight block cipher designed for consistent efficiency across FPGA, ASIC, and embedded software platforms.

The implementations and test materials correspond to the cipher specification and experimental results reported in the IEEE Access manuscript:

> **“SUWI: A Unified 128-bit Lightweight Block Cipher with Consistent Efficiency Across FPGA, ASIC, and Embedded Platforms”**
> W. A. Susantha Wijesinghe

---

## 1. Overview

SUWI is a 128-bit Feistel-based lightweight block cipher featuring:

* A 32-round symmetric Feistel structure
* A purely logical round function using AND, XOR, and fixed rotations
* S-box-free design for compact hardware realization
* On-the-fly round-key generation using an LFSR-based schedule
* Identical datapaths for encryption and decryption (reverse key order)

This repository supports **reproducibility and independent verification** of the cipher design, security analysis, and implementation claims presented in the paper.

---

## 2. Repository Structure

```
SUWI/
├── python/
│   └── suwi.py                 # Reference Python implementation
│
├── c/
│   └── suwi.c                  # Portable C implementation
│
├── verilog/                    
│   ├── suwi_enc.v             # Encription only
│   ├── suwi_enc_tb.v
│   ├── suwi_cipher.v          # Both Encryption and decryption
│   ├── suwi_cipher_tb.v
│   └── counter.v              # Cycle counter

├── test_vectors/
│   └── suwi_test_vectors.txt   # Reference plaintext–ciphertext pairs
│
├── LICENSE
└── README.md
```

---

## 3. Cipher Parameters

* **Block size:** 128 bits
* **Key size:** 128 bits
* **Structure:** Feistel network
* **Rounds:** 32
* **Round function:** AND, XOR, fixed rotations {2, 7, 11}
* **Round constant (CF):** `0x9e3779b97f4a7c15`
* **Key-mixing constant (CK):** `0xb5c0fbcfec4d3b2f`

All constants and operations match the specification in the manuscript.

---

## 4. Implementations

# Clone via HTTPS
```
git clone https://github.com/susantha-wijesinghe/suwi_cipher.git
cd suwi_cipher/Python
python suwi.py
```
### 4.1 Python

* algorithm validation,
* test vector generation,
* functional verification.

It follows the specification directly and prioritizes clarity over performance.

### 4.2 C

```
cd suwi_cipher/c
gcc -o suwi suwi.c
./suwi
```
The C implementation is:

* portable,
* written without platform-specific optimizations.


### 4.3 Verilog 

```
cd suwi_cipher/verilog
iverilog -o suwi_cipher.vvp suwi_cipher.v suwi_cipher_tb.v counter.
vvp suwi_cipher.vvp
```
The Verilog RTL corresponds to:

* an iterative, 1-round-per-cycle architecture,
* on-the-fly key scheduling,
* no final-round swap,
* identical encryption/decryption datapaths.

FPGA synthesis results reported in the paper target Xilinx Artix-7 devices.

---

## 5. Test Vectors

The repository includes reference test vectors to verify correctness across implementations.

Each test vector consists of:

* 128-bit plaintext
* 128-bit key
* 128-bit ciphertext

All implementations in this repository produce identical outputs for the provided vectors.

---

## 6. Reproducibility Notes

* The implementations are intended to reproduce **functional behavior**, not exact timing or power measurements.
* FPGA and ASIC results reported in the manuscript depend on synthesis tools, libraries, and constraints described in the paper.

---

## 7. License

This project is released under the **MIT License**, allowing free use for research and academic purposes.
If you use this code in academic work, please cite the corresponding paper.

---

## 8. Citation

If you use SUWI or this repository in your research, please cite:

```
W. A. Susantha Wijesinghe,
“SUWI: A Unified 128-bit Lightweight Block Cipher with Consistent Efficiency Across FPGA, ASIC, and Embedded Platforms,”
IEEE Access, 2026.
```

---

## 9. Contact

For questions, clarifications, or research collaboration:

**W. A. Susantha Wijesinghe**
Department of Electronics
Wayamba University of Sri Lanka
Email: [susantha@wyb.ac.lk](mailto:susantha@wyb.ac.lk)


