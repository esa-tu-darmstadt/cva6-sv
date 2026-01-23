module scaiev_fu import ariane_pkg::*; #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic
) (
    input  logic                              clk_i,
    input  logic                              rst_ni,
    input  fu_data_t                          fu_data_i,
    //from issue
    input  logic                              sv_valid_i,
    output logic                              sv_ready_o,
    input  logic [31:0]                       sv_off_instr_i,
    //to writeback
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0]  sv_trans_id_o,
    output exception_t                        sv_exception_o,
    output logic [CVA6Cfg.XLEN-1:0]           sv_result_o,
    output logic                              sv_valid_o,
    output logic                              sv_we_o,
    //to SCAIEV
    output logic [31:0] scaiev_execute_rdInstr,
    output logic [CVA6Cfg.XLEN-1:0] scaiev_execute_rdRS1,
    output logic [CVA6Cfg.XLEN-1:0] scaiev_execute_rdRS2,
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_execute_trans_id_o,

    output logic scaiev_execute_isValid,
    output logic scaiev_execute_isStalling,
    input  logic scaiev_execute_stall,

    input logic scaiev_execute_wrRD_valid,
    input logic scaiev_execute_hasWriteback,
    `ifdef SCAIEV_BRANCH
    input logic scaiev_execute_isBranch,
    `endif
    `ifdef SCAIEV_JUMP
    input logic scaiev_execute_isJump,
    `endif
    input logic [CVA6Cfg.XLEN-1:0] scaiev_execute_wrRD,
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_execute_trans_id_i,

    input logic scaiev_execute_semicoupled_deq, //Hide the pending instruction from FU so others can enter.
    input logic scaiev_execute_semicoupled_reenq //Commit a hidden instruction (regardless of stall input).
);

    logic execute_pending_r;

    always @(posedge clk_i) begin
        if (!rst_ni) begin
            execute_pending_r <= 1'b0;
        end
        else begin
            if (sv_valid_i) begin
                execute_pending_r <= execute_pending_r || (!sv_valid_o || scaiev_execute_semicoupled_reenq);
            end
            else if (sv_valid_o && !scaiev_execute_semicoupled_reenq) begin
                execute_pending_r <= 1'b0;
            end
            if (scaiev_execute_semicoupled_deq) begin
                execute_pending_r <= 1'b0;
            end
        end
    end

    assign sv_ready_o = !((sv_valid_i || execute_pending_r) && !scaiev_execute_semicoupled_deq && (scaiev_execute_semicoupled_reenq || scaiev_execute_stall));
    assign sv_trans_id_o = scaiev_execute_trans_id_i;
    assign sv_exception_o = '0;
    assign sv_valid_o = (
            !scaiev_execute_hasWriteback //Instr has no rd (still needs to report to writeback)
            || scaiev_execute_wrRD_valid
            `ifdef SCAIEV_BRANCH || scaiev_execute_isBranch `endif
            `ifdef SCAIEV_JUMP || scaiev_execute_isJump `endif
        ) && (scaiev_execute_isValid && !scaiev_execute_stall && !scaiev_execute_semicoupled_deq)
        || scaiev_execute_semicoupled_reenq; //works for R-Type instructions, TODO: Change for other instruction types
    assign sv_result_o = scaiev_execute_wrRD;
    assign sv_we_o = scaiev_execute_wrRD_valid;
    assign scaiev_execute_isValid = sv_valid_i || execute_pending_r;
    assign scaiev_execute_isStalling = !scaiev_execute_isValid && !scaiev_execute_semicoupled_reenq;
    assign scaiev_execute_rdInstr = sv_off_instr_i;
    assign scaiev_execute_rdRS1 = fu_data_i.operand_a;
    assign scaiev_execute_rdRS2 = fu_data_i.operand_b;
    assign scaiev_execute_trans_id_o = fu_data_i.trans_id;

endmodule
