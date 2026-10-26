`timescale 1ns / 1ps

// 8-bit Harvard RISC core with IF, ID, EX, MEM and WB pipeline stages.
// flags_out = {Z, C}; instr_done pulses when a valid instruction retires.
module risc8_5stage_core (
    input  wire       clk,
    input  wire       rst,
    output reg        halted,
    output wire [7:0] pc_out,
    output wire [1:0] flags_out,
    output reg        instr_done
);
    // IF stage and IF/ID pipeline register.
    reg  [7:0]  pc;
    wire [15:0] fetched_instruction;
    reg  [15:0] ifid_instruction;
    reg  [7:0]  ifid_pc;
    reg         ifid_valid;
    reg         halt_fetch;

    imem instruction_memory (
        .address(pc),
        .instruction(fetched_instruction)
    );

    // ID stage: field extraction, decode and register read.
    wire [3:0] id_opcode = ifid_instruction[15:12];
    wire [2:0] id_rd     = ifid_instruction[11:9];
    wire [2:0] id_rs1    = ifid_instruction[8:6];
    wire [2:0] id_rs2    = ifid_instruction[5:3];
    wire [7:0] id_imm8   = ifid_instruction[7:0];

    wire [2:0] id_alu_op;
    wire id_alu_src_imm, id_ra_is_rd, id_rb_is_rd;
    wire id_uses_a, id_uses_b, id_reg_we, id_mem_to_reg;
    wire id_mem_we, id_flag_we, id_jump, id_br_z, id_br_nz, id_halt;

    control_unit decoder (
        .opcode(id_opcode),
        .alu_op(id_alu_op),
        .alu_src_imm(id_alu_src_imm),
        .ra_is_rd(id_ra_is_rd),
        .rb_is_rd(id_rb_is_rd),
        .uses_a(id_uses_a),
        .uses_b(id_uses_b),
        .reg_we(id_reg_we),
        .mem_to_reg(id_mem_to_reg),
        .mem_we(id_mem_we),
        .flag_we(id_flag_we),
        .jump(id_jump),
        .br_z(id_br_z),
        .br_nz(id_br_nz),
        .halt(id_halt)
    );

    wire [2:0] id_src_a = id_ra_is_rd ? id_rd : id_rs1;
    wire [2:0] id_src_b = id_rb_is_rd ? id_rd : id_rs2;
    wire [7:0] id_data_a, id_data_b;
    wire       wb_write_enable;
    reg        memwb_valid;
    reg [7:0]  memwb_pc;
    reg [2:0]  memwb_rd;
    reg [7:0]  memwb_result;
    reg        memwb_reg_we, memwb_halt;

    regfile registers (
        .clk(clk),
        .rst(rst),
        .read_addr_a(id_src_a),
        .read_addr_b(id_src_b),
        .read_data_a(id_data_a),
        .read_data_b(id_data_b),
        .write_addr(memwb_rd),
        .write_data(memwb_result),
        .write_enable(wb_write_enable)
    );

    // ID/EX holds the read values and the register numbers. Both are needed:
    // the read value is the default, while the number selects forwarded data.
    reg        idex_valid;
    reg [7:0]  idex_pc;
    reg [2:0]  idex_rd, idex_src_a, idex_src_b;
    reg [7:0]  idex_data_a, idex_data_b, idex_imm8;
    reg [2:0]  idex_alu_op;
    reg        idex_alu_src_imm, idex_uses_a, idex_uses_b;
    reg        idex_reg_we, idex_mem_to_reg, idex_mem_we;
    reg        idex_flag_we, idex_jump, idex_br_z, idex_br_nz;
    reg        idex_halt;

    // EX/MEM pipeline register.
    reg        exmem_valid;
    reg [7:0]  exmem_pc;
    reg [2:0]  exmem_rd;
    reg [7:0]  exmem_alu_result, exmem_address, exmem_store_data;
    reg        exmem_reg_we, exmem_mem_to_reg, exmem_mem_we, exmem_halt;

    reg flag_z, flag_c;
    assign pc_out    = pc;
    assign flags_out = {flag_z, flag_c};
    assign wb_write_enable = memwb_valid && memwb_reg_we && !halted;

    // Hazard detection and EX operand forwarding.
    wire [1:0] id_fwd_a_sel, id_fwd_b_sel;
    reg  [1:0] fwd_a_sel, fwd_b_sel;
    wire stall;

    hazard_unit hazards (
        .id_valid(ifid_valid),
        .id_uses_a(id_uses_a),
        .id_uses_b(id_uses_b),
        .id_src_a(id_src_a),
        .id_src_b(id_src_b),
        .ex_valid(idex_valid),
        .ex_reg_we(idex_reg_we),
        .ex_is_load(idex_mem_to_reg),
        .ex_rd(idex_rd),
        .mem_valid(exmem_valid),
        .mem_reg_we(exmem_reg_we),
        .mem_rd(exmem_rd),
        .id_fwd_a_sel(id_fwd_a_sel),
        .id_fwd_b_sel(id_fwd_b_sel),
        .stall(stall)
    );

    reg [7:0] ex_operand_a, ex_operand_b_register;
    always @* begin
        case (fwd_a_sel)
            2'b10: ex_operand_a = exmem_alu_result;
            2'b01: ex_operand_a = memwb_result;
            default: ex_operand_a = idex_data_a;
        endcase
        case (fwd_b_sel)
            2'b10: ex_operand_b_register = exmem_alu_result;
            2'b01: ex_operand_b_register = memwb_result;
            default: ex_operand_b_register = idex_data_b;
        endcase
    end

    wire [7:0] ex_operand_b = idex_alu_src_imm
                            ? idex_imm8 : ex_operand_b_register;
    wire [7:0] alu_result;
    wire alu_zero, alu_carry;
    alu arithmetic_logic (
        .a(ex_operand_a),
        .b(ex_operand_b),
        .op(idex_alu_op),
        .result(alu_result),
        .zero(alu_zero),
        .carry(alu_carry)
    );

    // A branch uses the flags registered by any preceding EX instruction.
    wire branch_taken = idex_valid &&
                        (idex_jump || (idex_br_z && flag_z) ||
                         (idex_br_nz && !flag_z));
    wire ex_halt = idex_valid && idex_halt;

    // MEM stage. The address comes from rs1, including forwarded values.
    wire [7:0] memory_read_data;
    dmem data_memory (
        .clk(clk),
        .address(exmem_address),
        .write_data(exmem_store_data),
        .write_enable(exmem_valid && exmem_mem_we && !halted),
        .read_data(memory_read_data)
    );

    // One clocked process makes priority and pipeline movement explicit.
    always @(posedge clk) begin
        if (rst) begin
            pc <= 8'h00;
            halted <= 1'b0;
            halt_fetch <= 1'b0;
            instr_done <= 1'b0;
            flag_z <= 1'b0;
            flag_c <= 1'b0;

            ifid_instruction <= 16'h0000;
            ifid_pc <= 8'h00;
            ifid_valid <= 1'b0;

            idex_valid <= 1'b0;
            idex_pc <= 8'h00;
            idex_rd <= 3'd0;
            idex_src_a <= 3'd0;
            idex_src_b <= 3'd0;
            idex_data_a <= 8'h00;
            idex_data_b <= 8'h00;
            idex_imm8 <= 8'h00;
            idex_alu_op <= 3'd0;
            idex_alu_src_imm <= 1'b0;
            idex_uses_a <= 1'b0;
            idex_uses_b <= 1'b0;
            idex_reg_we <= 1'b0;
            idex_mem_to_reg <= 1'b0;
            idex_mem_we <= 1'b0;
            idex_flag_we <= 1'b0;
            idex_jump <= 1'b0;
            idex_br_z <= 1'b0;
            idex_br_nz <= 1'b0;
            idex_halt <= 1'b0;
            fwd_a_sel <= 2'b00;
            fwd_b_sel <= 2'b00;

            exmem_valid <= 1'b0;
            exmem_pc <= 8'h00;
            exmem_rd <= 3'd0;
            exmem_alu_result <= 8'h00;
            exmem_address <= 8'h00;
            exmem_store_data <= 8'h00;
            exmem_reg_we <= 1'b0;
            exmem_mem_to_reg <= 1'b0;
            exmem_mem_we <= 1'b0;
            exmem_halt <= 1'b0;

            memwb_valid <= 1'b0;
            memwb_pc <= 8'h00;
            memwb_rd <= 3'd0;
            memwb_result <= 8'h00;
            memwb_reg_we <= 1'b0;
            memwb_halt <= 1'b0;
        end else begin
            instr_done <= 1'b0;
            if (!halted) begin
                // WB retirement and permanent halt happen after older writes.
                instr_done <= memwb_valid;
                if (memwb_valid && memwb_halt)
                    halted <= 1'b1;

                // Flags are architecturally committed in EX.
                if (idex_valid && idex_flag_we) begin
                    flag_z <= alu_zero;
                    flag_c <= alu_carry;
                end

                if (ex_halt)
                    halt_fetch <= 1'b1;

                // IF priority: taken branch, halt, load-use stall, normal.
                if (branch_taken)
                    pc <= idex_imm8;
                else if (!ex_halt && !halt_fetch && !stall)
                    pc <= pc + 8'd1;

                if (branch_taken || ex_halt || halt_fetch) begin
                    ifid_valid <= 1'b0;
                end else if (!stall) begin
                    ifid_instruction <= fetched_instruction;
                    ifid_pc <= pc;
                    ifid_valid <= 1'b1;
                end

                // Payload always advances; the valid bit alone creates a
                // bubble. This keeps stall/flush off wide register enables.
                idex_valid <= ifid_valid &&
                              !(branch_taken || ex_halt || halt_fetch || stall);
                idex_pc <= ifid_pc;
                idex_rd <= id_rd;
                idex_src_a <= id_src_a;
                idex_src_b <= id_src_b;
                idex_data_a <= id_data_a;
                idex_data_b <= id_data_b;
                idex_imm8 <= id_imm8;
                idex_alu_op <= id_alu_op;
                idex_alu_src_imm <= id_alu_src_imm;
                idex_uses_a <= id_uses_a;
                idex_uses_b <= id_uses_b;
                idex_reg_we <= id_reg_we;
                idex_mem_to_reg <= id_mem_to_reg;
                idex_mem_we <= id_mem_we;
                idex_flag_we <= id_flag_we;
                idex_jump <= id_jump;
                idex_br_z <= id_br_z;
                idex_br_nz <= id_br_nz;
                idex_halt <= id_halt;
                fwd_a_sel <= id_fwd_a_sel;
                fwd_b_sel <= id_fwd_b_sel;

                // EX/MEM always takes the current EX instruction, even if
                // that instruction is a branch or HLT flushing younger work.
                exmem_valid <= idex_valid;
                exmem_pc <= idex_pc;
                exmem_rd <= idex_rd;
                exmem_alu_result <= alu_result;
                exmem_address <= ex_operand_a;
                exmem_store_data <= ex_operand_b_register;
                exmem_reg_we <= idex_valid && idex_reg_we;
                exmem_mem_to_reg <= idex_mem_to_reg;
                exmem_mem_we <= idex_valid && idex_mem_we;
                exmem_halt <= idex_valid && idex_halt;

                // MEM/WB captures the selected result after the memory stage.
                memwb_valid <= exmem_valid;
                memwb_pc <= exmem_pc;
                memwb_rd <= exmem_rd;
                memwb_result <= exmem_mem_to_reg
                              ? memory_read_data : exmem_alu_result;
                memwb_reg_we <= exmem_valid && exmem_reg_we;
                memwb_halt <= exmem_valid && exmem_halt;
            end
        end
    end
endmodule
