// suwi_enc_tb.v

// Verifies encryption using provided test vectors
// Author: W.A. Susantha Wijesinghe
// Email: susantha@wyb.ac.lk

// Date: August 07, 2025

`timescale 1ns / 1ps

module suwi_enc_tb;

    // Parameters
    parameter ROUNDS = 32;
    parameter WIDTH = 64;
    parameter CLK_PERIOD = 10; // 100 MHz clock

    // Signals
    reg clk;
    reg rst_n;
    reg start;
    reg [2*WIDTH-1:0] key;
    reg [2*WIDTH-1:0] text_in;
    wire [2*WIDTH-1:0] text_out;
    wire done;

    // Instantiate the DUT (Device Under Test)
    suwi_enc #(
        .ROUNDS(ROUNDS),
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .key(key),
        .text_in(text_in),
        .text_out(text_out),
        .done(done)
    );

    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Test vectors as arrays (Verilog 2005 compatible)
    reg [2*WIDTH-1:0] pt [0:5];
    reg [2*WIDTH-1:0] key_val [0:5];
    reg [2*WIDTH-1:0] ct [0:5];

    // Initialize test vectors
    initial begin
        pt[0] = 128'h00000000000000000000000000000000;
        key_val[0] = 128'h00000000000000000000000000000000;
        ct[0] = 128'h8f720e2a762337ccc6b89715e951caca;

        pt[1] = 128'hffffffffffffffffffffffffffffffff;
        key_val[1] = 128'hffffffffffffffffffffffffffffffff;
        ct[1] = 128'h4974d5f198cb10198f4018f644178a78;

        pt[2] = 128'h55555555555555555555555555555555;
        key_val[2] = 128'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
        ct[2] = 128'h9d31db4d608d320e7a0d133988fc5f3c;

        pt[3] = 128'h0123456789abcdef0123456789abcdef;
        key_val[3] = 128'hfedcba9876543210fedcba9876543210;
        ct[3] = 128'h0c4a442450f2bed27d88082a07874ee9;

        pt[4] = 128'ha1b2c3d4e5f60718a1b2c3d4e5f60718;
        key_val[4] = 128'h192a3b4c5d6e7f80192a3b4c5d6e7f80;
        ct[4] = 128'ha6c30b307209cdab8e7a3cd54da585b0;

        pt[5] = 128'h80000000000000000000000000000001;
        key_val[5] = 128'h7fffffffffffffffffffffffffffffff;
        ct[5] = 128'ha02e67d41f7e442e414ac016660b9c48;
    end

    // Test procedure
    integer i;
    reg [2*WIDTH-1:0] computed_ct;
    reg [2*WIDTH-1:0] recovered_pt;
    integer errors = 0;

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        start = 0;
        //decrypt = 0;
        key = 0;
        text_in = 0;

        // Apply reset
        #20 rst_n = 1;
        #20;

        $display("Starting SUWI Cipher Testbench Verification...");
        $display("Verifying %d test vectors for encryption.", 6);

        for (i = 0; i < 6; i = i + 1) begin
            $display("\nTest Vector #%0d:", i);

            // Encryption
            key = key_val[i];
            text_in = pt[i];
            start = 1;
            #CLK_PERIOD start = 0;

            // Wait for done
            wait(done == 1);
            #CLK_PERIOD;
            computed_ct = text_out;

            if (computed_ct == ct[i]) begin
                $display("Encryption PASS: Computed CT = %h, Expected CT = %h", computed_ct, ct[i]);
            end else begin
                $display("Encryption FAIL: Computed CT = %h, Expected CT = %h", computed_ct, ct[i]);
                errors = errors + 1;
            end

            # (20 * CLK_PERIOD);
        end

        if (errors == 0) begin
            $display("\nAll tests PASSED!");
        end else begin
            $display("\n%d errors detected.", errors);
        end

        $finish;
    end

    // Timeout mechanism
    initial begin
        # (10000 * CLK_PERIOD);  // Arbitrary large timeout
        $display("Simulation timeout reached. Possible hang in DUT.");
        $finish;
    end

endmodule