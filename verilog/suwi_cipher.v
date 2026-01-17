
// suwi_cipher.v 
//
// =============================================================================
// SUWI Lightweight Block Cipher (128-bit block / 128-bit key) - Reference RTL
// =============================================================================
//
// Purpose
// -------
// This RTL module implements the SUWI block cipher as described in the
// manuscript:
//   "SUWI: A Unified 128-bit Lightweight Block Cipher with Consistent Efficiency
//    Across FPGA, ASIC, and Embedded Platforms", IEEE Access, 2026.
//
// The RTL is intended to reproduce the functional behavior and architectural
// choices evaluated in the paper (iterative Feistel datapath with on-the-fly
// key scheduling). The design avoids S-boxes and modular addition for compact
// and timing-friendly implementation.
//
// Algorithm / Architecture Summary
// --------------------------------
// - Block size : 128 bits (L,R each 64 bits)
// - Key size   : 128 bits
// - Rounds     : 32
// - Datapath   : Iterative (typically 1 round per cycle; see paper configuration)
// - Round core : AND, XOR, fixed rotations {2, 7, 11}; no addition; no S-box
// - Key sched  : 64-bit round keys generated on-the-fly via LFSR (no key RAM)
// - Final swap : Omitted; ciphertext output is (L32 || R32)
// - Enc/Dec    : Identical datapath; decryption uses reversed round-key order
//
// Constants (as in the paper)
// ---------------------------
// - CF (round constant): 64'h9e3779b97f4a7c15
// - CK (key-mixing const): 64'hb5c0fbcfec4d3b2f
//
// Reproducibility Notes
// ---------------------
// - Cycle counts, throughput, and Fmax depend on constraints, toolchain, and
//   target device/library (FPGA/ASIC).
// - This RTL is written for clarity and correspondence to the manuscript.
//   Micro-optimizations (retiming, resource sharing, gating) are not mandatory
//   for functional verification.
//
// Repository
// ----------
// Release tag: v1.0-paper
//
// License
// -------
// MIT License (see LICENSE file in repository).
//
// Contact
// -------
// W. A. Susantha Wijesinghe, Wayamba University of Sri Lanka
// Email: susantha@wyb.ac.lk
// =============================================================================




`timescale 1ns / 1ps
module suwi_cipher #(
    parameter ROUNDS = 32,
    parameter WIDTH = 64 // half-block width
)(
    input wire clk,
    input wire rst_n, // active-low reset
    input wire start, // pulse to begin operation
    input wire decrypt, // 0 = encrypt, 1 = decrypt
    input wire [2*WIDTH-1:0] key, // 128-bit key: {key_high, key_low}
    input wire [2*WIDTH-1:0] text_in, // 128-bit plaintext/ciphertext
    output reg [2*WIDTH-1:0] text_out, // 128-bit output
    output reg done
);
    // Constants
    localparam [WIDTH-1:0] CONSTANT_F = 64'h9e3779b97f4a7c15;
    localparam [WIDTH-1:0] CONSTANT_K = 64'hb5c0fbcfec4d3b2f;
    // FSM states
    localparam IDLE = 2'd0;
    localparam ADVANCE = 2'd1;
    localparam ROUNDS_RUN = 2'd2;
    localparam FINISH = 2'd3;
    reg [1:0] state, next_state;

    // LFSR forward step (taps as per primitive polynomial x^64 + x^63 + x^61 + x^56 + x^31 + x^28 + x^23 + 1)
    function [WIDTH-1:0] lfsr_step;
        input [WIDTH-1:0] st;
        reg feedback;
        begin
            feedback = st[63] ^ st[61] ^ st[56] ^ st[31] ^ st[28] ^ st[23] ^ st[0];
            lfsr_step = {st[WIDTH-2:0], feedback};
        end
    endfunction

    // LFSR reverse step
    function [WIDTH-1:0] lfsr_reverse_step;
        input [WIDTH-1:0] st;
        reg feedback;
        begin
            feedback = st[0] ^ st[62] ^ st[57] ^ st[32] ^ st[29] ^ st[24] ^ st[1];
            lfsr_reverse_step = {feedback, st[WIDTH-1:1]};
        end
    endfunction

    // Rotation left
    function [WIDTH-1:0] rotl;
        input [WIDTH-1:0] in;
        input integer sh;
        begin
            rotl = (in << sh) | (in >> (WIDTH - sh));
        end
    endfunction

    // Round function
    function [WIDTH-1:0] round_fn;
        input [WIDTH-1:0] x;
        reg [WIDTH-1:0] t1, t2, t3;
        begin
            t1 = rotl(x, 2);
            t2 = rotl(x, 7);
            t3 = rotl(x, 11);
            round_fn = (t1 & t2) ^ t3 ^ CONSTANT_F;
        end
    endfunction

    // Internal registers
    reg [WIDTH-1:0] left_reg, right_reg;
    reg [WIDTH-1:0] lfsr_state;
    reg [WIDTH-1:0] key_low;
    reg [5:0] adv_cnt; // for LFSR advance
    reg [5:0] round_cnt; // up to 32
    wire [WIDTH-1:0] rk;
    wire [WIDTH-1:0] f_out;
    wire [WIDTH-1:0] temp;

    // On-the-fly round key
    assign rk = key_low ^ lfsr_state ^ CONSTANT_K;
    assign f_out = round_fn( (!decrypt) ? left_reg : right_reg );
    assign temp = (!decrypt) ? (right_reg ^ f_out ^ rk) : right_reg;

    // FSM sequential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            left_reg <= 0;
            right_reg <= 0;
            lfsr_state <= 1;
            key_low <= 0;
            adv_cnt <= 0;
            round_cnt <= 0;
            text_out <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        key_low <= key[WIDTH-1:0];
                        lfsr_state <= (key[2*WIDTH-1:WIDTH] != 0) ? key[2*WIDTH-1:WIDTH] : { {(WIDTH-1){1'b0}}, 1'b1 };
                        left_reg <= text_in[2*WIDTH-1:WIDTH];
                        right_reg <= text_in[WIDTH-1:0];
                        adv_cnt <= 0;
                        round_cnt <= 0;
                    end
                end
                ADVANCE: begin
                    lfsr_state <= lfsr_step(lfsr_state);
                    adv_cnt <= adv_cnt + 1;
                end
                ROUNDS_RUN: begin
                    if (round_cnt < ROUNDS) begin
                        if (!decrypt) begin
                            // Encryption
                            right_reg <= left_reg;
                            left_reg <= temp;
                            lfsr_state <= lfsr_step(lfsr_state);
                        end else begin
                            // Decryption
                            right_reg <= left_reg ^ f_out ^ rk;
                            left_reg <= temp;
                            lfsr_state <= lfsr_reverse_step(lfsr_state);
                        end
                        // Advance round counter only if not last
                        if (round_cnt != ROUNDS - 1)
                            round_cnt <= round_cnt + 1;
                    end
                end
                FINISH: begin
                    text_out <= {left_reg, right_reg};
                    done <= 1;
                end
            endcase
        end
    end

    // FSM combinational next state
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = decrypt ? ADVANCE : ROUNDS_RUN;
            end
            ADVANCE: begin
                if (adv_cnt == 30)
                    next_state = ROUNDS_RUN;
            end
            ROUNDS_RUN: begin
                if (round_cnt == ROUNDS - 1)
                    next_state = FINISH;
            end
            FINISH: begin
                if (!start)
                    next_state = IDLE;
            end
        endcase
    end
endmodule