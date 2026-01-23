package scaiev_config;
    //For scaiev_config_pkg files: Enable superscalar mode (1)
    localparam SCAIEVTargetSuperscalar = 0;
    //For scaiev wrapper: Assert RV32 (0) or RV64 (1) mode
    localparam SCAIEVTargetRV64 = 0;
    //Number of SCAIE-V EU ports
    localparam NrFUIssuePorts = 1;
    //Enable SCAIE-V decoupled writeback -> Issue forward.
    `ifdef SCAIEV_ENABLE
    localparam SpawnRDForward = 1;
    `else
    localparam SpawnRDForward = 0;
    `endif
endpackage
