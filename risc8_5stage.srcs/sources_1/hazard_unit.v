`timescale 1ns / 1ps

// Decide forwarding in ID, one cycle before the operand reaches EX.
// 10 selects the producer currently in EX (EX/MEM next cycle).
// 01 selects the producer currently in MEM (MEM/WB next cycle).
module hazard_unit (
    input  wire       id_valid,
    input  wire       id_uses_a,
    input  wire       id_uses_b,
    input  wire [2:0] id_src_a,
    input  wire [2:0] id_src_b,
    input  wire       ex_valid,
    input  wire       ex_reg_we,
    input  wire       ex_is_load,
    input  wire [2:0] ex_rd,
    input  wire       mem_valid,
    input  wire       mem_reg_we,
    input  wire [2:0] mem_rd,
    output reg  [1:0] id_fwd_a_sel,
    output reg  [1:0] id_fwd_b_sel,
    output wire       stall
);
    wire load_a = id_uses_a && id_src_a == ex_rd;
    wire load_b = id_uses_b && id_src_b == ex_rd;

    assign stall = id_valid && ex_valid && ex_is_load &&
                   (load_a || load_b);

    always @* begin
        id_fwd_a_sel = 2'b00;
        id_fwd_b_sel = 2'b00;

        if (id_valid && id_uses_a) begin
            if (ex_valid && ex_reg_we && !ex_is_load && id_src_a == ex_rd)
                id_fwd_a_sel = 2'b10;
            else if (mem_valid && mem_reg_we && id_src_a == mem_rd)
                id_fwd_a_sel = 2'b01;
        end

        if (id_valid && id_uses_b) begin
            if (ex_valid && ex_reg_we && !ex_is_load && id_src_b == ex_rd)
                id_fwd_b_sel = 2'b10;
            else if (mem_valid && mem_reg_we && id_src_b == mem_rd)
                id_fwd_b_sel = 2'b01;
        end
    end
endmodule
