import apb_global_pkg::*;

interface apb_interconnect
(
  input  logic pclk,
  input  logic preset_n,

  apb_if.apbMasterInterconnectMP master_if [NO_OF_MASTERS],
  apb_if.apbSlaveInterconnectMP  slave_if  [TOTAL_SLAVES]
);
  // ----------------------------
  // Bit widths needed to index masters/slaves
  // ----------------------------
  localparam int MID_W = (NO_OF_MASTERS <= 1) ? 1 : $clog2(NO_OF_MASTERS);
  localparam int SID_W = (TOTAL_SLAVES  <= 1) ? 1 : $clog2(TOTAL_SLAVES);

  // ----------------------------
  // Extended width to represent invalid slave index
  // ----------------------------
  localparam int SID_W_EXT = $clog2(TOTAL_SLAVES + 1);

  // ----------------------------
  // Invalid slave index - this slave will be used to drive pslverr for invalid addresses
  // The last slave (index TOTAL_SLAVES-1) is expected to be the "invalid slave agent"
  // ----------------------------
  localparam int INVALID_SLAVE_IDX = TOTAL_SLAVES - 1;

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
  logic s_pready  [TOTAL_SLAVES];
  logic [DATA_WIDTH-1:0] s_prdata [TOTAL_SLAVES];
  logic s_pslverr [TOTAL_SLAVES];

  generate
    for (s = 0; s < TOTAL_SLAVES; s++) begin
      always_comb begin
        s_pready[s]  = slave_if[s].pready;
        s_prdata[s]  = slave_if[s].prdata;
        s_pslverr[s] = slave_if[s].pslverr;
      end
    end
  endgenerate

  // ----------------------------
  // Slave Address Range Calculation
  // Valid Slaves (0 to TOTAL_SLAVES-2):
  //   Slave 0: min = 0, max = 2^SLAVE_MEMORY_SIZE - 1
  //   Slave i: min = prev_max + SLAVE_MEMORY_GAP
  //            max = min + 2^SLAVE_MEMORY_SIZE - 1
  // Invalid Slave (TOTAL_SLAVES-1): Handles invalid address accesses, drives pslverr
  // ----------------------------
  localparam longint SLAVE_SIZE = 2**SLAVE_MEMORY_SIZE;
  localparam longint SLAVE_BLOCK = SLAVE_SIZE + SLAVE_MEMORY_GAP;

  // Calculate min/max address for each valid slave (invalid slave has no address range)
  logic [ADDRESS_WIDTH-1:0] slave_min_addr [TOTAL_SLAVES];
  logic [ADDRESS_WIDTH-1:0] slave_max_addr [TOTAL_SLAVES];

  initial begin
    for (int i = 0; i < TOTAL_SLAVES - 1; i++) begin
      if (i == 0) begin
        slave_min_addr[i] = '0;
        slave_max_addr[i] = SLAVE_SIZE - 1;
      end else begin
        slave_min_addr[i] = slave_max_addr[i-1] + SLAVE_MEMORY_GAP;
        slave_max_addr[i] = slave_min_addr[i] + SLAVE_SIZE - 1;
      end
      $display("[APB_INTERCONNECT] Slave[%0d] Address Range: %0d - %0d",
               i, slave_min_addr[i], slave_max_addr[i]);
    end
    slave_min_addr[INVALID_SLAVE_IDX] = '1; // Set to max value (will never match)
    slave_max_addr[INVALID_SLAVE_IDX] = '0; // Set to 0 (invalid range)
    $display("[APB_INTERCONNECT] Slave[%0d] is INVALID SLAVE (handles address decode errors, drives pslverr)",
             INVALID_SLAVE_IDX);
  end

  // ----------------------------
  // Address decode: Returns slave index based on address range
  // Returns TOTAL_SLAVES (invalid marker) if address doesn't match any valid slave
  // Uses extended width (SID_W_EXT) to avoid truncation of invalid index
  // ----------------------------
  function automatic logic [SID_W_EXT-1:0] decode_slave(input logic [ADDRESS_WIDTH-1:0] addr);
    decode_slave = SID_W_EXT'(TOTAL_SLAVES); // Default: no match (invalid - maps to invalid slave)
    // Only check valid slaves (0 to TOTAL_SLAVES-2), slave TOTAL_SLAVES-1 is the invalid slave
    for (int i = 0; i < TOTAL_SLAVES - 1; i++) begin
      if (addr >= slave_min_addr[i] && addr <= slave_max_addr[i]) begin
        decode_slave = SID_W_EXT'(i);
        break;
      end
    end
  endfunction

  // Check if address is invalid (doesn't match any valid slave)
  function automatic logic is_invalid_addr(input logic [ADDRESS_WIDTH-1:0] addr);
    is_invalid_addr = (decode_slave(addr) == SID_W_EXT'(TOTAL_SLAVES));
  endfunction

  // ----------------------------
  // Requests (only during SETUP)
  // Valid slaves get requests based on address decode
  // Invalid slave (INVALID_SLAVE_IDX) gets requests for invalid addresses
  // ----------------------------
  logic [NO_OF_MASTERS-1:0] req [TOTAL_SLAVES];
  logic [NO_OF_MASTERS-1:0] req_d1 [TOTAL_SLAVES]; // For detection

  generate
    for (s = 0; s < TOTAL_SLAVES; s++) begin : G_REQ
      for (m = 0; m < NO_OF_MASTERS; m++) begin : G_REQM
        always_comb begin
          if (s == INVALID_SLAVE_IDX) begin
            req[s][m] = (m_psel[m] && !m_penable[m]) && is_invalid_addr(m_paddr[m]);
          end else begin
            req[s][m] = (m_psel[m] && !m_penable[m]) && (decode_slave(m_paddr[m]) == SID_W_EXT'(s));
          end
        end
      end
    end
  endgenerate

  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      for (int s = 0; s < TOTAL_SLAVES; s++) begin
        req_d1[s] <= '0;
      end
    end else begin
      for (int s = 0; s < TOTAL_SLAVES; s++) begin
        req_d1[s] <= req[s];
        
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
          if (req[s][m] && !req_d1[s][m]) begin
            if (s == INVALID_SLAVE_IDX) begin
              $display("[%0t] APB_INTERCONNECT: M%0d requests INVALID_SLAVE[%0d] (Invalid Addr=%0d)", 
                       $time, m, s, m_paddr[m]);
            end else begin
              $display("[%0t] APB_INTERCONNECT: M%0d requests Slave[%0d] (Addr=%0d, Write=%0d)", 
                       $time, m, s, m_paddr[m], m_pwrite[m]);
            end
          end
          else if (!req[s][m] && req_d1[s][m]) begin
            $display("[%0t] APB_INTERCONNECT: M%0d cancels request to Slave[%0d]", 
                     $time, m, s);
          end
        end
      end
    end
  end

  // ----------------------------
  // Per-slave ownership + RR pointer
  // ----------------------------
  logic                 slave_busy   [TOTAL_SLAVES];
  logic [MID_W-1:0]     owner        [TOTAL_SLAVES];
  logic [MID_W-1:0]     rr_ptr       [TOTAL_SLAVES];
  logic [NO_OF_MASTERS-1:0] grant    [TOTAL_SLAVES];

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
    for (s = 0; s < TOTAL_SLAVES; s++) begin : G_OWN
      always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
          rr_ptr[s]     <= '0;
          owner[s]      <= '0;
          slave_busy[s] <= 1'b0;
          $display("[%0t] APB_INTERCONNECT: RESET - Slave[%0d] idle", $time, s);
        end else begin
          if (xfer_done(s)) begin
            slave_busy[s] <= 1'b0;
            $display("[%0t] APB_INTERCONNECT: Slave[%0d] transfer COMPLETE with M%0d, now IDLE", 
                     $time, s, owner[s]);
          end

          if (!slave_busy[s] && (|grant[s])) begin
            for (int i = 0; i < NO_OF_MASTERS; i++) begin
              if (grant[s][i]) begin
                owner[s]      <= MID_W'(i);
                slave_busy[s] <= 1'b1;
                rr_ptr[s]     <= MID_W'((i + 1) % NO_OF_MASTERS);
                $display("[%0t] APB_INTERCONNECT: Slave[%0d] new OWNER=M%0d, Address=%0d, Write=%0d", 
                         $time, s, i, m_paddr[i], m_pwrite[i]);
                $display("[%0t] APB_INTERCONNECT: Slave[%0d] rr_ptr updated to %0d", 
                         $time, s, (i + 1) % NO_OF_MASTERS);
                break;
              end
            end
          end
        end
      end

      // combinational grant (only if not busy)
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

  always_ff @(posedge pclk) begin
    for (int s = 0; s < TOTAL_SLAVES; s++) begin
      if (!slave_busy[s] && (|req[s])) begin
        $display("[%0t] APB_INTERCONNECT: Slave[%0d] free, Requests: M0=%0d, M1=%0d, M2=%0d, M3=%0d", 
                 $time, s, req[s][0], req[s][1], req[s][2], req[s][3]);
      end
      
      for (int m = 0; m < NO_OF_MASTERS; m++) begin
        if (grant[s][m] && !slave_busy[s]) begin
          if (use_fixed_priority) begin
            $display("[%0t] APB_INTERCONNECT: Slave[%0d] FIXED_PRIORITY grant to M%0d", 
                     $time, s, m);
          end else begin
            $display("[%0t] APB_INTERCONNECT: Slave[%0d] ROUND_ROBIN grant to M%0d (rr_ptr=%0d)", 
                     $time, s, m, rr_ptr[s]);
          end
        end
      end
    end
  end

  // ----------------------------
  // Drive SLAVE side from current owner
  // ----------------------------
  generate
    for (s = 0; s < TOTAL_SLAVES; s++) begin : G_SDRV
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
  // ----------------------------
  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin : G_MRSP
      logic hit;
      logic [SID_W-1:0] sid;
      logic hit_d1;
      
      always_ff @(posedge pclk) begin
        hit_d1 <= hit;
      end

      always_comb begin
        hit = 1'b0;
        sid = '0;

        for (int ss = 0; ss < TOTAL_SLAVES; ss++) begin
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
      
      // Display master access status
      always_ff @(posedge pclk) begin
        if (hit && !hit_d1) begin
          $display("[%0t] APB_INTERCONNECT: M%0d now ACCESSING Slave[%0d]", 
                   $time, m, sid);
        end
        
        if (hit && s_pready[sid] && m_penable[m]) begin
          if (m_pwrite[m]) begin
            $display("[%0t] APB_INTERCONNECT: M%0d WRITE COMPLETE to Slave[%0d] Data=%0d", 
                     $time, m, sid, m_pwdata[m]);
          end else begin
            $display("[%0t] APB_INTERCONNECT: M%0d READ COMPLETE from Slave[%0d] Data=%0d", 
                     $time, m, sid, s_prdata[sid]);
          end
        end
        
        if (m_psel[m] && !m_penable[m] && !hit) begin
          $display("[%0t] APB_INTERCONNECT: M%0d STALLED waiting for slave access", 
                   $time, m);
        end
      end
    end
  endgenerate

  // ----------------------------
  // Periodic display of waiting states
  // ----------------------------
  int display_counter;
  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      display_counter <= 0;
    end else begin
      display_counter <= display_counter + 1;
      
      if (display_counter % 10 == 0) begin  // Display every 20 cycles
        $write("[%0t] APB_INTERCONNECT WAITING STATUS: ", $time);
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
          logic accessing;
          accessing = 1'b0;
          for (int s = 0; s < TOTAL_SLAVES; s++) begin
            if (slave_busy[s] && (owner[s] == MID_W'(m))) begin
              accessing = 1'b1;
              break;
            end
          end
          if (m_psel[m] && !m_penable[m]) begin
            if (!accessing) begin
              $write("M%0d[WAITING] ", m);
            end else begin
              $write("M%0d[ACTIVE] ", m);
            end
          end else begin
            $write("M%0d[IDLE] ", m);
          end
        end
        $display("");
        
        $write("[%0t] APB_INTERCONNECT SLAVE STATUS: ", $time);
        for (int s = 0; s < TOTAL_SLAVES; s++) begin
          if (slave_busy[s]) begin
            $write("S%0d[OWNER=M%0d] ", s, owner[s]);
          end else begin
            $write("S%0d[FREE] ", s);
          end
        end
        $display("");
      end
    end
  end

  // ----------------------------
  // Transaction summary display (can be called from testbench)
  // ----------------------------
  function void display_transaction_status();
    $display("\n[%0t] === APB INTERCONNECT TRANSACTION STATUS ===", $time);
    
    $display("MASTERS:");
    for (int m = 0; m < NO_OF_MASTERS; m++) begin
      string state;
      logic accessing;
      accessing = 1'b0;
      for (int s = 0; s < TOTAL_SLAVES; s++) begin
        if (slave_busy[s] && (owner[s] == MID_W'(m))) begin
          accessing = 1'b1;
          state = $sformatf("ACCESSING Slave[%0d]", s);
          break;
        end
      end
      if (!accessing) begin
        if (m_psel[m] && !m_penable[m]) begin
          state = "WAITING for slave";
        end else begin
          state = "IDLE";
        end
      end
      $display("  M%0d: %s (Addr=%0d, Psel=%0d, Penable=%0d)", 
               m, state, m_paddr[m], m_psel[m], m_penable[m]);
    end
    
    $display("\nSLAVES:");
    for (int s = 0; s < TOTAL_SLAVES; s++) begin
      string slave_type;
      if (s == INVALID_SLAVE_IDX) begin
        slave_type = "(INVALID/ERROR)";
      end else begin
        slave_type = $sformatf("(Valid: %0d-%0d)", 
                              slave_min_addr[s], slave_max_addr[s]);
      end
      
      if(slave_busy[s]) begin
        $display("  Slave[%0d] %s: BUSY serving M%0d, Pready=%0d", 
                 s, slave_type, owner[s], s_pready[s]);
      end else begin
        $display("  Slave[%0d] %s: FREE, rr_ptr=%0d", 
                 s, slave_type, rr_ptr[s]);
        if (|req[s]) begin
          $write("    Pending requests from: ");
          for (int m = 0; m < NO_OF_MASTERS; m++) begin
            if (req[s][m]) $write("M%0d ", m);
          end
          $display("");
        end
      end
    end
  endfunction

endinterface
