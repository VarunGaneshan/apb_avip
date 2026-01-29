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
  localparam longint SLAVE_SIZE = 2**SLAVE_MEMORY_SIZE;
  localparam longint total_valid_space = (TOTAL_SLAVES - 1) * SLAVE_SIZE;
  localparam longint total_gap_space = (TOTAL_SLAVES - 2) * SLAVE_MEMORY_GAP;

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
  logic [ADDRESS_WIDTH-1:0] current_addr;
	logic [MID_W-1:0] current_master;
				
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
  // Slave Address Range Calculation - FIXED VERSION
  // Valid Slaves (0 to TOTAL_SLAVES-2):
  //   Slave 0: min = 0, max = SLAVE_SIZE - 1
  //   Slave i: min = previous slave's max + SLAVE_MEMORY_GAP + 1
  //            max = min + SLAVE_SIZE - 1
  // Invalid Slave (TOTAL_SLAVES-1): Handles invalid address accesses
  // ----------------------------

  // Calculate min/max address for each valid slave (invalid slave has no address range)
  logic [ADDRESS_WIDTH-1:0] slave_min_addr [TOTAL_SLAVES];
  logic [ADDRESS_WIDTH-1:0] slave_max_addr [TOTAL_SLAVES];

  initial begin
    // Initialize invalid slave first
    slave_min_addr[INVALID_SLAVE_IDX] = '1; // Set to max value
    slave_max_addr[INVALID_SLAVE_IDX] = '0; // Set to 0
    
    // Calculate ranges for valid slaves
    for (int i = 0; i < TOTAL_SLAVES - 1; i++) begin
      if (i == 0) begin
        // First valid slave starts at 0
        slave_min_addr[i] = '0;
        slave_max_addr[i] = SLAVE_SIZE - 1;
      end else begin
        // Subsequent slaves start after previous slave's range + gap
        slave_min_addr[i] = slave_max_addr[i-1] + SLAVE_MEMORY_GAP + 1;
        slave_max_addr[i] = slave_min_addr[i] + SLAVE_SIZE - 1;
      end
      
      if (slave_max_addr[i] < slave_min_addr[i]) begin
        $display("[APB_INTERCONNECT ERROR] Address error for Slave[%0d]", i);
        $display("  Min: %0d, Max: %0d, Size: %0d", slave_min_addr[i], slave_max_addr[i], SLAVE_SIZE);
      end
      
      $display("[APB_INTERCONNECT] Slave[%0d] Address Range: %0d - %0d (Size: %0d)",i, slave_min_addr[i], slave_max_addr[i], slave_max_addr[i] - slave_min_addr[i] + 1);
    end
    
    $display("[APB_INTERCONNECT] Slave[%0d] is INVALID SLAVE (handles addresses outside valid ranges)",
             INVALID_SLAVE_IDX);
    
    if (SLAVE_MEMORY_GAP > 0) begin
      $display("[APB_INTERCONNECT] Memory gap between slaves: %0d bytes", SLAVE_MEMORY_GAP);
    end
    
    if (TOTAL_SLAVES > 1) begin
      $display("[APB_INTERCONNECT] Total valid address space: %0d bytes", total_valid_space);
      $display("[APB_INTERCONNECT] Total gap space: %0d bytes", total_gap_space);
    end
  end

  // ----------------------------
  // Address decode: Returns slave index based on address range
  // Returns TOTAL_SLAVES (invalid marker) if address doesn't match any valid slave
  // ----------------------------
  function automatic logic [SID_W_EXT-1:0] decode_slave(input logic [ADDRESS_WIDTH-1:0] addr);
    decode_slave = SID_W_EXT'(TOTAL_SLAVES); // Default: no match (invalid)
    
    // Only check valid slaves (0 to TOTAL_SLAVES-2)
    for (int i = 0; i < TOTAL_SLAVES - 1; i++) begin
      // Check if address is within this slave's range
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
  // Additional debug function to show where address falls
  // ----------------------------
  function automatic void debug_address(input logic [ADDRESS_WIDTH-1:0] addr, input int master_idx);
    logic [SID_W_EXT-1:0] decoded;
    decoded = decode_slave(addr);
    
    if (decoded == SID_W_EXT'(TOTAL_SLAVES)) begin
      $display("[APB_INTERCONNECT DEBUG] M%0d address %0d is INVALID", master_idx, addr);
      $display("  Not in any valid slave range:");
      for (int i = 0; i < TOTAL_SLAVES - 1; i++) begin
        $display("    Slave[%0d]: %0d - %0d", i, slave_min_addr[i], slave_max_addr[i]);
      end
    end else begin
      $display("[APB_INTERCONNECT DEBUG] M%0d address %0d maps to Slave[%0d]",
               master_idx, addr, decoded);
    end
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
            // Invalid slave gets requests for addresses that don't match any valid slave
            req[s][m] = (m_psel[m] && !m_penable[m]) && is_invalid_addr(m_paddr[m]);
          end else begin
            // Valid slaves get requests based on address decode
            req[s][m] = (m_psel[m] && !m_penable[m]) && (decode_slave(m_paddr[m]) == SID_W_EXT'(s));
          end
        end
      end
    end
  endgenerate

  // ----------------------------
  // Debug: Monitor address decoding
  // ----------------------------
  always_ff @(posedge pclk) begin
    for (int m = 0; m < NO_OF_MASTERS; m++) begin
      if (m_psel[m] && !m_penable[m]) begin
        // when master starts a new request
        logic [SID_W_EXT-1:0] decoded;
        decoded = decode_slave(m_paddr[m]);
        
        if (decoded == SID_W_EXT'(TOTAL_SLAVES)) begin
          $display("[%0t] APB_INTERCONNECT: M%0d starting INVALID access to addr %0d",
                   $time, m, m_paddr[m]);
          
          // Show why it's invalid
          for (int i = 0; i < TOTAL_SLAVES - 1; i++) begin
            if (m_paddr[m] < slave_min_addr[i]) begin
              $display("  Address %0d is below Slave[%0d] range (%0d-%0d)",
                       m_paddr[m], i, slave_min_addr[i], slave_max_addr[i]);
              break;
            end else if (m_paddr[m] > slave_max_addr[i]) begin
              if (i == TOTAL_SLAVES - 2) begin
                $display("  Address %0d is above last valid Slave[%0d] range (%0d-%0d)",
                         m_paddr[m], i, slave_min_addr[i], slave_max_addr[i]);
              end else if (m_paddr[m] < slave_min_addr[i+1]) begin
                $display("  Address %0d is in gap between Slave[%0d] and Slave[%0d]",
                         m_paddr[m], i, i+1);
                $display("  Gap: %0d bytes after Slave[%0d] max %0d",
                         SLAVE_MEMORY_GAP, i, slave_max_addr[i]);
              end
						end
          end
        end
      end
    end
  end

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
              // Call debug function to show why it's invalid
              debug_address(m_paddr[m], m);
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

  // FIX: Add transaction tracking to prevent pready routing issues
  typedef struct packed {
    logic [MID_W-1:0] master_id;
    logic is_valid;
  } pending_xfer_t;

  pending_xfer_t pending_xfer [TOTAL_SLAVES];
  logic [MID_W-1:0] response_owner [TOTAL_SLAVES];

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
          pending_xfer[s].is_valid <= 1'b0;
          pending_xfer[s].master_id <= '0;
          response_owner[s] <= '0;
          $display("[%0t] APB_INTERCONNECT: RESET - Slave[%0d] idle", $time, s);
        end else begin
          // Release slave when transfer completes
          if (xfer_done(s)) begin
            slave_busy[s] <= 1'b0;
            pending_xfer[s].is_valid <= 1'b0;
            $display("[%0t] APB_INTERCONNECT: Slave[%0d] transfer COMPLETE with M%0d, now IDLE",
                     $time, s, owner[s]);
          end

          // Latch new owner when granting and slave not busy
          if (!slave_busy[s] && (|grant[s])) begin
            for (int i = 0; i < NO_OF_MASTERS; i++) begin
              if (grant[s][i]) begin
                owner[s]      <= MID_W'(i);
                slave_busy[s] <= 1'b1;
                rr_ptr[s]     <= MID_W'((i + 1) % NO_OF_MASTERS);

                // FIX: Register which master started this transaction
                pending_xfer[s].master_id <= MID_W'(i);
                pending_xfer[s].is_valid <= 1'b1;
                response_owner[s] <= MID_W'(i);

                $display("[%0t] APB_INTERCONNECT: Slave[%0d] new OWNER=M%0d, Address=%0d, Write=%0d",
                         $time, s, i, m_paddr[i], m_pwrite[i]);
                $display("[%0t] APB_INTERCONNECT: Slave[%0d] rr_ptr updated to %0d",
                         $time, s, (i + 1) % NO_OF_MASTERS);
                break;
              end
            end
          end
          
          // FIX: Maintain response owner during ACCESS phase
          if (slave_busy[s] && m_psel[owner[s]] && m_penable[owner[s]]) begin
            response_owner[s] <= owner[s];
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
      // Display free slave status with pending requests
      if (!slave_busy[s] && (|req[s])) begin
        $write("[%0t] APB_INTERCONNECT: Slave[%0d] free, Requests: ", $time, s);
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
          if (req[s][m]) begin
            $write("M%0d ", m);
          end
        end
        $display("");
      end

      // Display grant decisions
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
  // Helper function to route responses
  function automatic void route_response(
    input int slave_idx,
    input logic s_pready_arr [TOTAL_SLAVES],
    input logic [DATA_WIDTH-1:0] s_prdata_arr [TOTAL_SLAVES],
    input logic s_pslverr_arr [TOTAL_SLAVES],
    output logic pready,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic pslverr
  );
    case (slave_idx)
      0: begin
        if (0 < TOTAL_SLAVES) begin
          pready = s_pready_arr[0];
          prdata = s_prdata_arr[0];
          pslverr = s_pslverr_arr[0];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      1: begin
        if (1 < TOTAL_SLAVES) begin
          pready = s_pready_arr[1];
          prdata = s_prdata_arr[1];
          pslverr = s_pslverr_arr[1];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      2: begin
        if (2 < TOTAL_SLAVES) begin
          pready = s_pready_arr[2];
          prdata = s_prdata_arr[2];
          pslverr = s_pslverr_arr[2];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      3: begin
        if (3 < TOTAL_SLAVES) begin
          pready = s_pready_arr[3];
          prdata = s_prdata_arr[3];
          pslverr = s_pslverr_arr[3];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      4: begin
        if (4 < TOTAL_SLAVES) begin
          pready = s_pready_arr[4];
          prdata = s_prdata_arr[4];
          pslverr = s_pslverr_arr[4];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      5: begin
        if (5 < TOTAL_SLAVES) begin
          pready = s_pready_arr[5];
          prdata = s_prdata_arr[5];
          pslverr = s_pslverr_arr[5];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      6: begin
        if (6 < TOTAL_SLAVES) begin
          pready = s_pready_arr[6];
          prdata = s_prdata_arr[6];
          pslverr = s_pslverr_arr[6];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      7: begin
        if (7 < TOTAL_SLAVES) begin
          pready = s_pready_arr[7];
          prdata = s_prdata_arr[7];
          pslverr = s_pslverr_arr[7];
        end else begin
          pready = 1'b0;
          prdata = '0;
          pslverr = 1'b0;
        end
      end
      default: begin
        pready = 1'b0;
        prdata = '0;
        pslverr = 1'b0;
      end
    endcase
  endfunction

  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin : G_MRSP
      logic responding;
      logic [SID_W-1:0] slave_for_response;
      logic local_pready, local_pslverr;
      logic [DATA_WIDTH-1:0] local_prdata;

      always_comb begin
        responding = 1'b0;
        slave_for_response = '0;

        // Determine which slave is handling this master's transaction
        for (int s = 0; s < TOTAL_SLAVES; s++) begin
          // Check pending transaction struct
          if (pending_xfer[s].is_valid &&
              pending_xfer[s].master_id == MID_W'(m) &&
              slave_busy[s]) begin
            responding = 1'b1;
            slave_for_response = SID_W'(s);
          end

          // Check response owner (backup)
          if (response_owner[s] == MID_W'(m) && slave_busy[s]) begin
            responding = 1'b1;
            slave_for_response = SID_W'(s);
          end
        end

        // Use helper function to route responses
        route_response(
          slave_for_response,
          s_pready,
          s_prdata,
          s_pslverr,
          local_pready,
          local_prdata,
          local_pslverr
        );
        
        // Route response to master interface
        master_if[m].pready  = responding ? local_pready : 1'b0;
        master_if[m].prdata  = responding ? local_prdata : '0;
        master_if[m].pslverr = responding ? local_pslverr : 1'b0;
      end

      // Display master access status
      always_ff @(posedge pclk) begin
        static logic responding_d1 = 0;

        if (responding && !responding_d1) begin
          $display("[%0t] APB_INTERCONNECT: M%0d now ACCESSING Slave[%0d]",
                   $time, m, slave_for_response);
        end

        responding_d1 = responding;

        // Display transfer completion
        if (responding) begin
          logic current_pready;
          logic [DATA_WIDTH-1:0] current_prdata;
          logic current_pslverr;

          route_response(
            slave_for_response,
            s_pready,
            s_prdata,
            s_pslverr,
            current_pready,
            current_prdata,
            current_pslverr
          );

          if (current_pready && m_penable[m]) begin
            if (m_pwrite[m]) begin
              $display("[%0t] APB_INTERCONNECT: M%0d WRITE COMPLETE to Slave[%0d] Data=%0d",
                       $time, m, slave_for_response, m_pwdata[m]);
            end else begin
              $display("[%0t] APB_INTERCONNECT: M%0d READ COMPLETE from Slave[%0d] Data=%0d",
                       $time, m, slave_for_response, current_prdata);
            end
          end
        end

        // Display when master is stalled (waiting)
        if (m_psel[m] && !m_penable[m] && !responding) begin
          $display("[%0t] APB_INTERCONNECT: M%0d STALLED waiting for slave access",
                   $time, m);
        end
      end
    end
  endgenerate

  // ----------------------------
  // Debug: Monitor for pready routing and invalid address handling
  // ----------------------------
  always_ff @(posedge pclk) begin
    for (int s = 0; s < TOTAL_SLAVES; s++) begin
      if (slave_busy[s]) begin
        // Track which addresses are being accessed
        current_master = owner[s];
        current_addr = m_paddr[current_master];
        
        if (s == INVALID_SLAVE_IDX) begin
          $display("[%0t] APB_INTERCONNECT DEBUG: Invalid slave busy with M%0d, Addr=%0d",
                   $time, current_master, current_addr);
          
          // Verify this is actually an invalid address
          if (!is_invalid_addr(current_addr)) begin
            $display("[%0t] APB_INTERCONNECT ERROR: Addr=%0d should be invalid but decode_slave returned %0d",
                     $time, current_addr, decode_slave(current_addr));
          end
				end 
        
        if (s_pready[s]) begin
          $display("[%0t] APB_INTERCONNECT DEBUG: Slave[%0d] pready=1 for M%0d",
                   $time, s, current_master);
        end
      end
    end
  end

  // ----------------------------
  // Periodic display of waiting states
  // ----------------------------
  int display_counter;
  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      display_counter <= 0;
    end else begin
      display_counter <= display_counter + 1;

      if (display_counter % 20 == 0) begin
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
        $display("  Slave[%0d] %s: BUSY serving M%0d (pending M%0d), Pready=%0d, Addr=%0d",
                 s, slave_type, owner[s], pending_xfer[s].master_id, s_pready[s], m_paddr[owner[s]]);
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
    $display("============================================\n");
  endfunction

endinterface
