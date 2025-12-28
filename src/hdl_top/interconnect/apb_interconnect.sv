import apb_global_pkg::*;
 
interface apb_interconnect #(
  parameter int NO_OF_MASTERS = 2,
  parameter int NO_OF_SLAVES  = 4
)(
  input  logic pclk,
  input  logic preset_n,
 
  apb_if.apbMasterInterconnectMP master_if [NO_OF_MASTERS],
  apb_if.apbSlaveInterconnectMP  slave_if  [NO_OF_SLAVES]
);
 
  // ----------------------------
  // Bit widths needed to index masters/slaves
  // ----------------------------
  localparam int MID_W = (NO_OF_MASTERS <= 1) ? 1 : $clog2(NO_OF_MASTERS);
  localparam int SID_W = (NO_OF_SLAVES  <= 1) ? 1 : $clog2(NO_OF_SLAVES);
 
  // ----------------------------
  // Extended width to represent invalid slave index
  // ----------------------------
  localparam int SID_W_EXT = $clog2(NO_OF_SLAVES + 1);
 
  // ----------------------------
  // Invalid slave index - this slave will be used to drive pslverr for invalid addresses
  // The last slave (index NO_OF_SLAVES-1) is expected to be the "invalid slave agent"
  // ----------------------------
  localparam int INVALID_SLAVE_IDX = NO_OF_SLAVES - 1;
 
  // ----------------------------
  // Arbitration scheme selection via plusargs
  // Use +FIXED_PRIORITY for fixed priority arbitration (Master 0 highest)
  // Default is Round-Robin arbitration
  // ----------------------------
  logic use_fixed_priority;
 
  initial begin
    use_fixed_priority = $test$plusargs("FIXED_PRIORITY");
    if (use_fixed_priority)
      $display("[APB_INTERCONNECT] Using FIXED PRIORITY arbitration (Master 0 = highest priority)");
    else
      $display("[APB_INTERCONNECT] Using ROUND-ROBIN arbitration");
  end
 
  // ----------------------------
  // Collect master signals
  // ----------------------------
  logic                     m_psel    [NO_OF_MASTERS];
  logic                     m_penable [NO_OF_MASTERS];
  logic [ADDRESS_WIDTH-1:0] m_paddr   [NO_OF_MASTERS];
  logic                     m_pwrite  [NO_OF_MASTERS];
  logic [(DATA_WIDTH/8)-1:0] m_pstrb  [NO_OF_MASTERS];
  logic [DATA_WIDTH-1:0]    m_pwdata  [NO_OF_MASTERS];
  logic [2:0]               m_pprot   [NO_OF_MASTERS];
 
  genvar m, s;
  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin
      always_comb begin
        m_psel[m]    = master_if[m].psel;
        m_penable[m] = master_if[m].penable;
        m_paddr[m]   = master_if[m].paddr;
        m_pwrite[m]  = master_if[m].pwrite;
        m_pstrb[m]   = master_if[m].pstrb;
        m_pwdata[m]  = master_if[m].pwdata;
        m_pprot[m]   = master_if[m].pprot;
      end
    end
  endgenerate
 
  // ----------------------------
  // Collect slave response signals
  // ----------------------------
  logic s_pready  [NO_OF_SLAVES];
  logic [DATA_WIDTH-1:0] s_prdata [NO_OF_SLAVES];
  logic s_pslverr [NO_OF_SLAVES];
 
  generate
    for (s = 0; s < NO_OF_SLAVES; s++) begin
      always_comb begin
        s_pready[s]  = slave_if[s].pready;
        s_prdata[s]  = slave_if[s].prdata;
        s_pslverr[s] = slave_if[s].pslverr;
      end
    end
  endgenerate
 
  // ----------------------------
  // Slave Address Range Calculation
  // Valid Slaves (0 to NO_OF_SLAVES-2):
  //   Slave 0: min = 0, max = 2^SLAVE_MEMORY_SIZE - 1
  //   Slave i: min = prev_max + SLAVE_MEMORY_GAP
  //            max = min + 2^SLAVE_MEMORY_SIZE - 1
  // Invalid Slave (NO_OF_SLAVES-1): Handles invalid address accesses, drives pslverr
  // ----------------------------
  localparam longint SLAVE_SIZE = 2**SLAVE_MEMORY_SIZE;
  localparam longint SLAVE_BLOCK = SLAVE_SIZE + SLAVE_MEMORY_GAP;
 
  // Calculate min/max address for each valid slave (invalid slave has no address range)
  logic [ADDRESS_WIDTH-1:0] slave_min_addr [NO_OF_SLAVES];
  logic [ADDRESS_WIDTH-1:0] slave_max_addr [NO_OF_SLAVES];
 
  initial begin
    // Configure address ranges for valid slaves only (0 to NO_OF_SLAVES-2)
    for (int i = 0; i < NO_OF_SLAVES - 1; i++) begin
      if (i == 0) begin
        slave_min_addr[i] = '0;
        slave_max_addr[i] = SLAVE_SIZE - 1;
      end else begin
        slave_min_addr[i] = slave_max_addr[i-1] + SLAVE_MEMORY_GAP + 1;
        slave_max_addr[i] = slave_min_addr[i] + SLAVE_SIZE - 1;
      end
      $display("[APB_INTERCONNECT] Slave[%0d] Address Range: 0x%0h - 0x%0h",
               i, slave_min_addr[i], slave_max_addr[i]);
    end
    // Invalid slave has no valid address range
    slave_min_addr[INVALID_SLAVE_IDX] = '1; // Set to max value (will never match)
    slave_max_addr[INVALID_SLAVE_IDX] = '0; // Set to 0 (invalid range)
    $display("[APB_INTERCONNECT] Slave[%0d] is INVALID SLAVE (handles address decode errors, drives pslverr)",
             INVALID_SLAVE_IDX);
  end
 
  // ----------------------------
  // Address decode: Returns slave index based on address range
  // Returns NO_OF_SLAVES (invalid marker) if address doesn't match any valid slave
  // Uses extended width (SID_W_EXT) to avoid truncation of invalid index
  // ----------------------------
  function automatic logic [SID_W_EXT-1:0] decode_slave(input logic [ADDRESS_WIDTH-1:0] addr);
    decode_slave = SID_W_EXT'(NO_OF_SLAVES); // Default: no match (invalid - maps to invalid slave)
    // Only check valid slaves (0 to NO_OF_SLAVES-2), slave NO_OF_SLAVES-1 is the invalid slave
    for (int i = 0; i < NO_OF_SLAVES - 1; i++) begin
      if (addr >= slave_min_addr[i] && addr <= slave_max_addr[i]) begin
        decode_slave = SID_W_EXT'(i);
        break;
      end
    end
  endfunction
 
  // Check if address is invalid (doesn't match any valid slave)
  function automatic logic is_invalid_addr(input logic [ADDRESS_WIDTH-1:0] addr);
    is_invalid_addr = (decode_slave(addr) == SID_W_EXT'(NO_OF_SLAVES));
  endfunction
 
  // ----------------------------
  // Requests (only during SETUP)
  // Valid slaves get requests based on address decode
  // Invalid slave (INVALID_SLAVE_IDX) gets requests for invalid addresses
  // ----------------------------
  logic [NO_OF_MASTERS-1:0] req [NO_OF_SLAVES];
 
  generate
    for (s = 0; s < NO_OF_SLAVES; s++) begin : G_REQ
      for (m = 0; m < NO_OF_MASTERS; m++) begin : G_REQM
        always_comb begin
          if (s == INVALID_SLAVE_IDX) begin
            // Invalid slave receives requests for addresses that don't match any valid slave
            req[s][m] = (m_psel[m] && !m_penable[m]) && is_invalid_addr(m_paddr[m]);
          end else begin
            // Valid slaves receive requests based on address decode
            req[s][m] = (m_psel[m] && !m_penable[m]) && (decode_slave(m_paddr[m]) == SID_W_EXT'(s));
          end
        end
      end
    end
  endgenerate
 
  // ----------------------------
  // Per-slave ownership + RR pointer
  // ----------------------------
  /*
  slave_busy[s]  // Is slave currently serving a master?
  owner[s]       // Which master owns this slave?
  rr_ptr[s]      // Round-robin pointer for fair arbitration
  grant[s]       // One-hot grant signal per slave
  */
  logic                 slave_busy   [NO_OF_SLAVES];
  logic [MID_W-1:0]     owner        [NO_OF_SLAVES];
  logic [MID_W-1:0]     rr_ptr       [NO_OF_SLAVES];
  logic [NO_OF_MASTERS-1:0] grant    [NO_OF_SLAVES];
 
  // A transfer completes when owner has ACCESS and slave is ready
  function automatic logic xfer_done(input int sid);
    logic [MID_W-1:0] om;
    om = owner[sid];
    xfer_done = slave_busy[sid] &&
                m_psel[om] && m_penable[om] &&
                s_pready[sid];
  endfunction
 
  // RR pointer update + busy/owner update
  generate
    for (s = 0; s < NO_OF_SLAVES; s++) begin : G_OWN
      always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
          rr_ptr[s]     <= '0;
          owner[s]      <= '0;
          slave_busy[s] <= 1'b0;
        end else begin
          // release when transfer completes
          if (xfer_done(s)) begin
            slave_busy[s] <= 1'b0;
          end
 
          // latch new owner when granting and slave not busy
          if (!slave_busy[s] && (|grant[s])) begin
            for (int i = 0; i < NO_OF_MASTERS; i++) begin
              if (grant[s][i]) begin
                owner[s]      <= MID_W'(i);
                slave_busy[s] <= 1'b1;
                rr_ptr[s]     <= MID_W'((i + 1) % NO_OF_MASTERS);
                break;
              end
            end
          end
        end
      end
 
      // combinational grant (only if not busy)
      // Supports both Fixed Priority and Round-Robin arbitration
      always_comb begin
        grant[s] = '0;
 
        if (!slave_busy[s]) begin
          if (use_fixed_priority) begin
            // Fixed Priority: Master 0 has highest priority, Master N-1 has lowest
            for (int k = 0; k < NO_OF_MASTERS; k++) begin
              if (req[s][k]) begin
                grant[s][k] = 1'b1;
                break;
              end
            end
          end else begin
            // Round-Robin: Start from rr_ptr and wrap around
            for (int k = 0; k < NO_OF_MASTERS; k++) begin
              int idx;
              idx = (rr_ptr[s] + k) % NO_OF_MASTERS;
              if (req[s][idx]) begin
                grant[s][idx] = 1'b1;
                break;
              end
            end
          end
        end
      end
    end
  endgenerate
 
  // ----------------------------
  // Drive SLAVE side from current owner (or from granted master during SETUP)
  // Strategy:
  //   - If busy: forward signals from owner
  //   - Else if a grant exists: forward from granted master (SETUP cycle)
  //   - Else drive IDLE
  // ----------------------------
  generate
    for (s = 0; s < NO_OF_SLAVES; s++) begin : G_SDRV
      logic [MID_W-1:0] sel_m;
 
      always_comb begin
        // choose which master to forward
        sel_m = owner[s];
        if (!slave_busy[s]) begin
          for (int i = 0; i < NO_OF_MASTERS; i++) begin
            if (grant[s][i]) begin
              sel_m = MID_W'(i);
              break;
            end
          end
        end
 
        // defaults: idle
        slave_if[s].psel    = 1'b0;
        slave_if[s].penable = 1'b0;
        slave_if[s].paddr   = '0;
        slave_if[s].pwrite  = 1'b0;
        slave_if[s].pstrb   = '0;
        slave_if[s].pwdata  = '0;
        slave_if[s].pprot   = '0;
 
        // forward if busy or granted
        if (slave_busy[s] || (|grant[s])) begin
          slave_if[s].psel    = m_psel[sel_m];
          slave_if[s].penable = m_penable[sel_m];
          slave_if[s].paddr   = m_paddr[sel_m];
          slave_if[s].pwrite  = m_pwrite[sel_m];
          slave_if[s].pstrb   = m_pstrb[sel_m];
          slave_if[s].pwdata  = m_pwdata[sel_m];
          slave_if[s].pprot   = m_pprot[sel_m];
        end
      end
    end
  endgenerate
 
  // ----------------------------
  // Return response to MASTER side
  // - If a master owns some slave: return that slave's response
  // - Otherwise: stall the master (pready=0)
  // a master will have at most one outstanding APB transfer.
  // ----------------------------
  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin : G_MRSP
      logic hit;
      logic [SID_W-1:0] sid;
 
 
      always_comb begin
        hit = 1'b0;
        sid = '0;
 
        for (int ss = 0; ss < NO_OF_SLAVES; ss++) begin
          if (slave_busy[ss] && (owner[ss] == MID_W'(m))) begin
            hit = 1'b1;
            sid = SID_W'(ss);
            break;
          end
        end
 
        // defaults: stall/zero
        master_if[m].pready  = 1'b0;
        master_if[m].prdata  = '0;
        master_if[m].pslverr = 1'b0;
 
        if (hit) begin
          master_if[m].pready  = s_pready[sid];
          master_if[m].prdata  = s_prdata[sid];
          master_if[m].pslverr = s_pslverr[sid];
        end
      end
    end
  endgenerate
 
endinterface
