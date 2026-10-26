`timescale 1ns / 1ps

// CPU instruction decoder. All outputs have safe NOP defaults.
module control_unit (
    input  wire [3:0] opcode,
    output reg  [2:0] alu_op,
    output reg        alu_src_imm,
    output reg        ra_is_rd,
    output reg        rb_is_rd,
    output reg        uses_a,
    output reg        uses_b,
    output reg        reg_we,
    output reg        mem_to_reg,
    output reg        mem_we,
    output reg        flag_we,
    output reg        jump,
    output reg        br_z,
    output reg        br_nz,
    output reg        halt
);
    always @* begin
        alu_op      = 3'd0;
        alu_src_imm = 1'b0;
        ra_is_rd    = 1'b0;
        rb_is_rd    = 1'b0;
        uses_a      = 1'b0;
        uses_b      = 1'b0;
        reg_we      = 1'b0;
        mem_to_reg  = 1'b0;
        mem_we      = 1'b0;
        flag_we     = 1'b0;
        jump        = 1'b0;
        br_z        = 1'b0;
        br_nz       = 1'b0;
        halt        = 1'b0;

        case (opcode)
            4'h0: begin end // NOP
            4'h1: begin // ADD rd, rs1, rs2
                alu_op = 3'd0; uses_a = 1'b1; uses_b = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'h2: begin // SUB
                alu_op = 3'd1; uses_a = 1'b1; uses_b = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'h3: begin // AND
                alu_op = 3'd2; uses_a = 1'b1; uses_b = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'h4: begin // OR
                alu_op = 3'd3; uses_a = 1'b1; uses_b = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'h5: begin // XOR
                alu_op = 3'd4; uses_a = 1'b1; uses_b = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'h6: begin // SHL rd, rs1
                alu_op = 3'd5; uses_a = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'h7: begin // SHR rd, rs1
                alu_op = 3'd6; uses_a = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'h8: begin // LDI rd, imm8
                alu_op = 3'd7; alu_src_imm = 1'b1; reg_we = 1'b1;
            end
            4'h9: begin // ADDI rd, imm8
                alu_op = 3'd0; alu_src_imm = 1'b1;
                ra_is_rd = 1'b1; uses_a = 1'b1;
                reg_we = 1'b1; flag_we = 1'b1;
            end
            4'hA: begin // LD rd, [rs1]
                uses_a = 1'b1; reg_we = 1'b1; mem_to_reg = 1'b1;
            end
            4'hB: begin // ST rd, [rs1]
                uses_a = 1'b1; uses_b = 1'b1;
                rb_is_rd = 1'b1; mem_we = 1'b1;
            end
            4'hC: jump  = 1'b1;
            4'hD: br_z  = 1'b1;
            4'hE: br_nz = 1'b1;
            4'hF: halt  = 1'b1;
            default: begin end
        endcase
    end
endmodule
