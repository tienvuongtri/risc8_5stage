`timescale 1ns / 1ps

// Self-contained 256 x 16 ROM. Unlisted locations are NOP (16'h0000).
// The comments show the assembly program used by the self-checking testbench.
module imem (
    input  wire [7:0]  address,
    output wire [15:0] instruction
);
    reg [15:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 16'h0000;

        mem[ 0] = 16'h8205; // LDI R1, 05
        mem[ 1] = 16'h8403; // LDI R2, 03
        mem[ 2] = 16'h1650; // ADD R3, R1, R2
        mem[ 3] = 16'h28C8; // SUB R4, R3, R1 (WB-to-ID bypass)
        mem[ 4] = 16'h3AE0; // AND R5, R3, R4 -> Z=1
        mem[ 5] = 16'hD008; // BZ 08 (taken)
        mem[ 6] = 16'h8EEE; // wrong path
        mem[ 7] = 16'h8EDD; // wrong path
        mem[ 8] = 16'h4A50; // OR R5, R1, R2 -> 07, Z=0
        mem[ 9] = 16'hE00C; // BNZ 0C (taken)
        mem[10] = 16'h8ECC; // wrong path
        mem[11] = 16'h8EBB; // wrong path
        mem[12] = 16'h5C50; // XOR R6, R1, R2 -> 06
        mem[13] = 16'h6D80; // SHL R6, R6 -> 0C
        mem[14] = 16'h7D80; // SHR R6, R6 -> 06
        mem[15] = 16'h8820; // LDI R4, 20
        mem[16] = 16'hB700; // ST R3, [R4] -> mem[20]=08
        mem[17] = 16'hAB00; // LD R5, [R4] -> 08
        mem[18] = 16'h1D50; // ADD R6, R5, R2 -> 0B (load-use stall)
        mem[19] = 16'h9CF5; // ADDI R6, F5 -> 00, Z=1, C=1
        mem[20] = 16'hD017; // BZ 17 (taken)
        mem[21] = 16'h8EAA; // wrong path
        mem[22] = 16'h8EBB; // wrong path
        mem[23] = 16'h800F; // LDI R0, 0F (R0 is writable)
        mem[24] = 16'h1E10; // ADD R7, R0, R2 -> 12
        mem[25] = 16'h2E80; // SUB R7, R2, R0 -> F4, borrow=1
        mem[26] = 16'hE01D; // BNZ 1D (taken)
        mem[27] = 16'h8EEE; // wrong path
        mem[28] = 16'h8EFF; // wrong path
        mem[29] = 16'h0000; // NOP
        mem[30] = 16'h9E0B; // ADDI R7, 0B -> FF, Z=0
        mem[31] = 16'hD022; // BZ 22 (not taken)
        mem[32] = 16'hC023; // JMP 23 (taken)
        mem[33] = 16'h8EAB; // wrong path
        mem[34] = 16'h8ECD; // wrong path
        mem[35] = 16'h8080; // LDI R0, 80
        mem[36] = 16'h6000; // SHL R0, R0 -> 00, C=1, Z=1
        mem[37] = 16'hD028; // BZ 28 (taken)
        mem[38] = 16'h8EEE; // wrong path
        mem[39] = 16'h8EDD; // wrong path
        mem[40] = 16'h8001; // LDI R0, 01
        mem[41] = 16'h7000; // SHR R0, R0 -> 00, C=1, Z=1
        mem[42] = 16'hE02D; // BNZ 2D (not taken)
        mem[43] = 16'h0000; // NOP
        mem[44] = 16'h0000; // NOP
        mem[45] = 16'hF000; // HLT
        mem[46] = 16'h8E99; // must be squashed by HLT
        mem[47] = 16'h8EAA; // must be squashed by HLT
    end

    assign instruction = mem[address];
endmodule
