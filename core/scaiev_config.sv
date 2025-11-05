package scaiev_config;
    //Enable SCAIE-V decoupled writeback -> Issue forward.
    `ifdef SCAIEV_ENABLE
    localparam SpawnRDForward = 1;
    `else
    localparam SpawnRDForward = 0;
    `endif
endpackage
