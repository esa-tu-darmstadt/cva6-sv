// Copyright 2017-2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.03.2017
// Description: CVA6 Top-level module

`include "rvfi_types.svh"
`include "cvxif_types.svh"

module cva6_glue_wrapper import ariane_pkg::*; #(
    // CVA6 config
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),

    // RVFI PROBES
    parameter type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg),
    parameter type rvfi_probes_csr_t = `RVFI_PROBES_CSR_T(CVA6Cfg),
    parameter type rvfi_probes_t = struct packed {
      rvfi_probes_csr_t   csr;
      rvfi_probes_instr_t instr;
    },

    `ifdef SCAIEV_ZOL
    localparam ICACHE_DREQID_WIDTH = 2,
    localparam type icache_dreqid_t = logic [ICACHE_DREQID_WIDTH-1:0],
    localparam INSTRQUEUE_ID_WIDTH = $clog2(ariane_pkg::FETCH_FIFO_DEPTH) + $clog2(CVA6Cfg.INSTR_PER_FETCH), //FETCH_FIFO_DEPTH=4 (high), CVA6Cfg.INSTR_PER_FETCH=2 (low)
    `endif

    // AXI types
    parameter type axi_ar_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_aw_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_w_chan_t = struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    },
    parameter type b_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type r_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type noc_req_t = struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    },
    parameter type noc_resp_t = struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    },
    parameter type scaiev_instr_decoded_t = struct packed {
      logic [4:0] rd; //'0 if unused by instr
      logic rd_fpr; //rd is in the FPR space
      logic [4:0] rs1; //'0 if unused by instr
      logic rs1_fpr; //rs1 is in the FPR space
      logic [4:0] rs2; //'0 if unused by instr
      logic rs2_fpr; //rs2 is in the FPR space
      logic [4:0] rs3; //may be non-zero even if unused by instr
      logic rs3_valid; //rs3 is valid
      logic rs3_fpr; //rs3 is in the FPR space
    },
    parameter type scaiev_id_pipeinto_t = struct packed {
      logic decode1_decode0; //Pipe: Decode port 1 -> Decode port 0
      logic issue1_issue0; //Pipe: Issue port 1 -> Issue port 0
      logic [CVA6Cfg.NrIssuePorts-1:0] decode0_issue; //Pipe: Decode port 0 -> Issue port i
      logic decode1_issue1; //Pipe: Decode port 1 -> Issue port 1
    },
    //
    parameter type readregflags_t = `READREGFLAGS_T(CVA6Cfg),
    parameter type writeregflags_t = `WRITEREGFLAGS_T(CVA6Cfg),
    parameter type id_t = `ID_T(CVA6Cfg),
    parameter type hartid_t = `HARTID_T(CVA6Cfg),
    parameter type x_compressed_req_t = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
    parameter type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),
    parameter type x_issue_req_t = `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_issue_resp_t = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
    parameter type x_register_t = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
    parameter type x_commit_t = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_result_t = `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),
    parameter type cvxif_req_t =
    `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_req_t, x_commit_t),
    parameter type cvxif_resp_t =
    `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t)
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Reset boot address - SUBSYSTEM
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    // Hard ID reflected as CSR - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Inter-processor (async) interrupt - SUBSYSTEM
    input logic ipi_i,
    // Timer (async) interrupt - SUBSYSTEM
    input logic time_irq_i,
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // Probes to build RVFI, can be left open when not used - RVFI
    output rvfi_probes_t rvfi_probes_o,
    // CVXIF request - SUBSYSTEM
    output cvxif_req_t cvxif_req_o,
    // CVXIF response - SUBSYSTEM
    input cvxif_resp_t cvxif_resp_i,
    // noc request, can be AXI or OpenPiton - SUBSYSTEM
    output noc_req_t noc_req_o,
    // noc response, can be AXI or OpenPiton - SUBSYSTEM
    input noc_resp_t noc_resp_i

);
`ifdef SCAIEV_ENABLE
  if (CVA6Cfg.XLEN == 64 && !scaiev_config::SCAIEVTargetRV64) begin
    $error("SCAIE-V mismatching target (core is RV64, expected RV32)");
  end
  else if (CVA6Cfg.XLEN == 32 && scaiev_config::SCAIEVTargetRV64) begin
    $error("SCAIE-V mismatching target (core is RV32, expected RV64)");
  end
  logic [CVA6Cfg.XLEN-1:0] scaiev_fetch_PC;
  logic scaiev_fetch_isStalling;
  logic scaiev_fetch_isFlushing;
  logic scaiev_fetch_isReplaying;
  logic scaiev_fetch_ignoreReplay;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] scaiev_realign_isValid;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0][31:0] scaiev_realign_rdInstr;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0][CVA6Cfg.XLEN-1:0] scaiev_realign_PC;
  logic scaiev_decode_isFlushing;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isStalling;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_stall;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isValid;
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] scaiev_decode_rdInstr;
  scaiev_instr_decoded_t [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_decInstr;
  scaiev_id_pipeinto_t scaiev_id_pipeinto;
  logic scaiev_realign_isFlushing;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] scaiev_realign_isStalling;
  logic scaiev_issue_isFlushing;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_issue_isStalling;
  logic scaiev_flush_ctrl_id;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_issue_isValid;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_issue_pipeinto_scaievfu;
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] scaiev_issue_rdRS1;
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] scaiev_issue_rdRS2;
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] scaiev_issue_rdInstr;
  logic scaiev_scoreboard_isFlushing;
  logic scaiev_execute_isValid;
  logic scaiev_execute_isStalling;
  logic scaiev_execute_stall;
  logic scaiev_execute_hasWriteback;
  logic scaiev_execute_isFlushing;
  logic scaiev_execute_isNew;
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] scaiev_issue_PC;
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_issue_trans_id_o;
  logic [31:0] scaiev_execute_rdInstr;
  logic [CVA6Cfg.XLEN-1:0] scaiev_execute_rdRS1;
  logic [CVA6Cfg.XLEN-1:0] scaiev_execute_rdRS2;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_execute_trans_id_o;
  logic [CVA6Cfg.XLEN-1:0] scaiev_execute_rdMem_result;
  logic scaiev_execute_rdMem_result_valid;

  logic scaiev_execute_semicoupled_deq;
  logic scaiev_execute_semicoupled_reenq;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_execute_rdMem_result_trans_id;
  logic scaiev_execute_rdMem_result_has_trans_id;
  logic [CVA6Cfg.NrCommitPorts-1:0] scaiev_commit_trans_id_valid;
  logic [CVA6Cfg.NrCommitPorts-1:0] scaiev_commit_drop;
  logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_commit_trans_id;
  logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] scaiev_commit_PC;

  logic [CVA6Cfg.XLEN-1:0] scaiev_fetch_wrPC;
  logic scaiev_fetch_wrPCValid;
  logic scaiev_fetch_stall;
  logic scaiev_realign_isBranch;
  logic scaiev_realign_isJump;
  //logic scaiev_realign_isZOLJump;
  //logic [63:0] scaiev_realign_jumpAddr;
  logic scaiev_decode_flush;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isSCAIEV;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isSCAIEV_hasRS1;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isSCAIEV_hasRS2;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isSCAIEV_hasRD;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isSCAIEV_hasRD_decoupled;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isBranch;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isLoad;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_decode_isStore;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_issue_stall;
  logic scaiev_issue_flush;
  logic [CVA6Cfg.NrIssuePorts-1:0] scaiev_issue_mem_stall;
  logic scaiev_execute_mem_ready;
  logic scaiev_execute_lsuvalid; //regular LSU op in Execute
  logic scaiev_execute_rdMem_valid;
  logic scaiev_execute_wrRD_valid;
  logic scaiev_execute_isJump;
  logic [CVA6Cfg.VLEN-1:0] scaiev_execute_jumpAddress;
  logic [CVA6Cfg.XLEN-1:0] scaiev_execute_wrRD;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_execute_trans_id_i;
  logic scaiev_execute_isBranch;
  logic scaiev_execute_branch_isTaken;
  logic scaiev_execute_wrMem_valid;
  logic [CVA6Cfg.XLEN-1:0] scaiev_execute_wrMem;
  logic [CVA6Cfg.XLEN-1:0] scaiev_execute_memAddr;
  logic [2:0] scaiev_execute_memSize;
  logic scaiev_execute_memAddr_valid;
  logic scaiev_execute_wrMem_suppress_wb;
  logic scaiev_execute_mem_has_trans_id;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] scaiev_execute_mem_trans_id;

  logic scaiev_writeback_spawn_valid;
  logic [CVA6Cfg.XLEN-1:0] scaiev_writeback_spawn_data;
  logic [4:0] scaiev_writeback_spawn_addr;

  icache_dreqid_t scaiev_fetch_reqID;
  icache_dreqid_t scaiev_realign_reqID;
  icache_dreqid_t scaiev_fetch_reqID_flushFrom;
  logic [$bits(icache_dreqid_t):0] scaiev_fetch_reqID_flushCount;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0][INSTRQUEUE_ID_WIDTH-1:0] scaiev_realign_instrqueueID;
  logic [CVA6Cfg.NrIssuePorts-1:0][INSTRQUEUE_ID_WIDTH-1:0] scaiev_decode_instrqueueID;
  logic [CVA6Cfg.VLEN-1:0] scaiev_decode_pcOverride;
  logic scaiev_decode_pcOverride_valid;
  logic scaiev_realign_fully_unaligned;
`endif

logic clk;
logic rst;
logic rst_i;
assign clk = clk_i;
assign rst = ~rst_ni;
assign rst_i = ~rst_ni;

cva6 #(
  .CVA6Cfg ( CVA6Cfg ),
  `ifdef SCAIEV_ZOL
  .icache_dreqid_t ( icache_dreqid_t ),
  .INSTRQUEUE_ID_WIDTH ( INSTRQUEUE_ID_WIDTH ),
  `endif
  `ifdef SCAIEV_ENABLE
  .scaiev_instr_decoded_t ( scaiev_instr_decoded_t ),
  .scaiev_id_pipeinto_t ( scaiev_id_pipeinto_t ),
  `endif
  .rvfi_probes_instr_t ( rvfi_probes_instr_t ),
  .rvfi_probes_csr_t ( rvfi_probes_csr_t ),
  .rvfi_probes_t ( rvfi_probes_t ),
  .axi_ar_chan_t (axi_ar_chan_t),
  .axi_aw_chan_t (axi_aw_chan_t),
  .axi_w_chan_t (axi_w_chan_t),
  .noc_req_t (noc_req_t),
  .noc_resp_t (noc_resp_t)
) i_cva6 (
  .*
);
`ifdef SCAIEV_ENABLE
scaiev_glue #(
    .CVA6Cfg ( CVA6Cfg ),
    .INSTRQUEUE_ID_WIDTH ( INSTRQUEUE_ID_WIDTH ),
    .scaiev_instr_decoded_t ( scaiev_instr_decoded_t ),
    .scaiev_id_pipeinto_t ( scaiev_id_pipeinto_t )
) glue(
  .*
);
`endif
endmodule
