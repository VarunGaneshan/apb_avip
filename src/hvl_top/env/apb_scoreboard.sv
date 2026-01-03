`ifndef APB_SCOREBOARD_INCLUDED_
`define APB_SCOREBOARD_INCLUDED_

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_tlm_analysis_fifo #(apb_master_tx) apb_master_analysis_fifo[];
  uvm_tlm_analysis_fifo #(apb_slave_tx)  apb_slave_analysis_fifo[];

  int apb_master_tx_count[];
  int apb_slave_tx_count[];

  // declaring handle for the env config
  apb_env_config apb_env_cfg_h;

  bit [31:0] SLAVE_START_ADDR[];
  bit [31:0] SLAVE_END_ADDR[];

  // COMPARISON COUNTERS PER MASTER
  int apb_master_pwdata_pass[];
  int apb_master_pwdata_fail[];
  int apb_master_paddr_pass[];
  int apb_master_paddr_fail[];
  int apb_master_pwrite_pass[];
  int apb_master_pwrite_fail[];
  int apb_master_pprot_pass[];
  int apb_master_pprot_fail[];
  int apb_master_pstrb_pass[];
  int apb_master_pstrb_fail[];

  // COMPARISON COUNTERS PER SLAVE
  int apb_slave_prdata_pass[];
  int apb_slave_prdata_fail[];
  int apb_slave_pslverr_pass[];
  int apb_slave_pslverr_fail[];

  int match_found_count = 0;
  int match_fail_count = 0;

  // Expected Queues: One queue per slave to store predicted transactions
  apb_master_tx slave_expected_q[int][$];

  // master tx id queue to know which master is sending the data
  int slave_expected_id_q[int][$];

  // memory for reference prdata prediction
  bit [DATA_WIDTH-1:0] mem[int][int];

  extern function new(string name="apb_scoreboard", uvm_component parent=null);
  extern function void build_phase(uvm_phase phase);
  extern function int get_slave_index(bit [31:0] addr);
  extern function void ref_model(apb_master_tx m_tx, int slave_idx);
  extern task run_phase(uvm_phase phase);
  extern function void compare_trans(apb_master_tx m_tx, apb_slave_tx s_tx, int master_idx, int slave_idx);
  extern function void check_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);

endclass

function apb_scoreboard::new(string name = "apb_scoreboard", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void apb_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);

  apb_master_analysis_fifo = new[NO_OF_MASTERS];
  apb_slave_analysis_fifo = new[NO_OF_SLAVES];

  foreach (apb_master_analysis_fifo[i]) begin
    apb_master_analysis_fifo[i] = new($sformatf("apb_master_analysis_fifo[%0d]", i), this);
  end

  foreach (apb_slave_analysis_fifo[i]) begin
    apb_slave_analysis_fifo[i] = new($sformatf("apb_slave_analysis_fifo[%0d]", i), this);
  end

  // Allocate per master arrays
  apb_master_tx_count        = new[NO_OF_MASTERS];
  apb_master_pwdata_pass     = new[NO_OF_MASTERS];
  apb_master_pwdata_fail     = new[NO_OF_MASTERS];
  apb_master_paddr_pass      = new[NO_OF_MASTERS];
  apb_master_paddr_fail      = new[NO_OF_MASTERS];
  apb_master_pwrite_pass     = new[NO_OF_MASTERS];
  apb_master_pwrite_fail     = new[NO_OF_MASTERS];
  apb_master_pprot_pass      = new[NO_OF_MASTERS];
  apb_master_pprot_fail      = new[NO_OF_MASTERS];
  apb_master_pstrb_pass      = new[NO_OF_MASTERS];
  apb_master_pstrb_fail      = new[NO_OF_MASTERS];

  // Allocate per slave arrays
  apb_slave_tx_count         = new[NO_OF_SLAVES];
  apb_slave_prdata_pass      = new[NO_OF_SLAVES];
  apb_slave_prdata_fail      = new[NO_OF_SLAVES];
  apb_slave_pslverr_pass     = new[NO_OF_SLAVES];
  apb_slave_pslverr_fail     = new[NO_OF_SLAVES];

  // Initialize the values
  foreach(apb_master_tx_count[i]) begin
    apb_master_tx_count[i] = 0;
    apb_master_pwdata_pass[i] = 0;
    apb_master_pwdata_fail[i] = 0;
    apb_master_paddr_pass[i] = 0;
    apb_master_paddr_fail[i] = 0;
    apb_master_pwrite_pass[i] = 0;
    apb_master_pwrite_fail[i] = 0;
    apb_master_pprot_pass[i] = 0;
    apb_master_pprot_fail[i] = 0;
    apb_master_pstrb_pass[i] = 0;
    apb_master_pstrb_fail[i] = 0;
  end

  foreach(apb_slave_tx_count[i]) begin
    apb_slave_tx_count[i] = 0;
    apb_slave_prdata_pass[i] = 0;
    apb_slave_prdata_fail[i] = 0;
    apb_slave_pslverr_pass[i] = 0;
    apb_slave_pslverr_fail[i] = 0;
  end

  // Get slave addr ranges
  SLAVE_START_ADDR = new[NO_OF_SLAVES];
  SLAVE_END_ADDR = new[NO_OF_SLAVES];

  foreach(SLAVE_START_ADDR[i]) begin
    if(!uvm_config_db#(apb_slave_agent_config)::get(this, "", $sformatf("SLAVE_START_ADDR[%0d]",i), SLAVE_START_ADDR[i]))
      `uvm_fatal(get_type_name(), $sformatf("SLAVE%0d_START_ADDR not set", i))
    if(!uvm_config_db#(apb_slave_agent_config)::get(this, "", $sformatf("SLAVE_END_ADDR[%0d]",i), SLAVE_END_ADDR[i]))
      `uvm_fatal(get_type_name(), $sformatf("SLAVE%0d_END_ADDR not set", i))
  end
endfunction

function void apb_scoreboard::ref_model(apb_master_tx m_tx, int slave_idx);

  if (m_tx.pwrite == 1) begin
    // Write operation: update memory based on pstrb signal
    for (int i = 0; i < DATA_WIDTH/8; i++) begin
      if (m_tx.pstrb[i]) begin
        mem[slave_idx][m_tx.paddr + i] = m_tx.pwdata[8*i+7 -: 8];
        $display("DATA IS WRITTEN INTO MEM[SLAVE%0d] at address 0x%0h", slave_idx, m_tx.paddr + i);
      end
    end
  end
  else begin
    // Read operation: predict prdata from memory
    for (int i = 0; i < DATA_WIDTH/8; i++) begin
      if (mem[slave_idx].exists(m_tx.paddr + i)) begin
        m_tx.prdata[8*i+7 -: 8] = mem[slave_idx][m_tx.paddr + i];
      end
      else begin
        m_tx.prdata[8*i+7 -: 8] = 8'h00; // default value in memory
      end
    end
  end

endfunction

task apb_scoreboard::run_phase(uvm_phase phase);
  super.run_phase(phase);

  // Separate every master and slave, creating a thread for each
  foreach(apb_master_analysis_fifo[i]) begin
    automatic int master_idx = i;
    fork
      forever begin
        apb_master_tx m_tx;
        int slave_idx;
        apb_master_analysis_fifo[master_idx].get(m_tx);
        apb_master_tx_count[master_idx]++;

        // Routing information to check which slave it's accessing
        slave_idx = get_slave_index(m_tx.paddr);

        if(slave_idx == -1) begin
          `uvm_error("SCB", $sformatf("Address 0x%0h does not map to any valid slave", m_tx.paddr))
        end
        else begin
          // Update the ref model to predict the prdata
          ref_model(m_tx, slave_idx);

          // Push into the specific slave's expected queue
          slave_expected_q[slave_idx].push_back(m_tx);
          // Push which master is sending the data to the slave
          slave_expected_id_q[slave_idx].push_back(master_idx);
          `uvm_info("SCB", $sformatf("Master[%0d] sent TX to Slave[%0d]", master_idx, slave_idx), UVM_HIGH)
        end
      end
    join_none
  end

  // Get the slave transactions from the fifo for each slave using fork join for each slave
  foreach(apb_slave_analysis_fifo[i]) begin
    automatic int s_index = i;
    fork
      forever begin
        apb_slave_tx s_tx;
        apb_master_tx exp_tx;
        int master_id;

        // Get transaction from Slave
        apb_slave_analysis_fifo[s_index].get(s_tx);
        apb_slave_tx_count[s_index]++;

        // CHECK: Do we have an expected transaction for this slave?
        if(slave_expected_q[s_index].size() == 0) begin
          `uvm_error("SCB", $sformatf("Slave[%0d] received unexpected transaction!", s_index))
          match_fail_count++;
        end
        else begin
          // Pop the oldest expected transaction
          exp_tx = slave_expected_q[s_index].pop_front();
          master_id = slave_expected_id_q[s_index].pop_front();
          `uvm_info("SCB", $sformatf("Slave[%0d] match found for ADDR=0x%0h", s_index, s_tx.paddr), UVM_HIGH)
          // Compare
          compare_trans(exp_tx, s_tx, master_id, s_index);
        end
      end
    join_none
  end

  // Wait for all the threads to complete
  wait fork;
endtask

// Get the specific slave IDs / customize this based on your design spec
function int apb_scoreboard::get_slave_index(bit [31:0] addr);
  for(int i = 0; i < NO_OF_SLAVES; i++) begin
    if(addr >= SLAVE_START_ADDR[i] && addr <= SLAVE_END_ADDR[i]) begin
      return i;
    end
  end
  `uvm_error(get_type_name(), $sformatf("Address 0x%8h does not map to any slave", addr))
  return -1;
endfunction

function void apb_scoreboard::compare_trans(apb_master_tx m_tx, apb_slave_tx s_tx, int master_idx, int slave_idx);

  if (m_tx.pwrite == 1) begin
    // WRITE Transaction Comparison
    `uvm_info(get_type_name(),
      "-- --------------------------------- APB SCOREBOARD COMPARISONS [WRITE] ---------------------------------",
      UVM_NONE)

    if (m_tx.pwdata == s_tx.pwdata) begin
      `uvm_info(get_type_name(), "APB PWDATA match", UVM_NONE);
      `uvm_info("SB_PWDATA_MATCH",
        $sformatf("Master PWDATA = 0x%0h Slave PWDATA = 0x%0h", m_tx.pwdata, s_tx.pwdata),
        UVM_HIGH);
      apb_master_pwdata_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PWDATA_MISMATCH",
        $sformatf("Master PWDATA = 0x%0h Slave PWDATA = 0x%0h", m_tx.pwdata, s_tx.pwdata));
      apb_master_pwdata_fail[master_idx]++;
    end

    if (m_tx.paddr == s_tx.paddr) begin
      `uvm_info(get_type_name(), "APB PADDR match", UVM_HIGH);
      `uvm_info("SB_PADDR_MATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h", m_tx.paddr, s_tx.paddr),
        UVM_HIGH);
      apb_master_paddr_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PADDR_MISMATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h", m_tx.paddr, s_tx.paddr));
      apb_master_paddr_fail[master_idx]++;
    end

    if (m_tx.pwrite == s_tx.pwrite) begin
      `uvm_info(get_type_name(), "APB PWRITE match", UVM_HIGH);
      `uvm_info("SB_PWRITE_MATCH",
        $sformatf("Master PWRITE = %0d Slave PWRITE = %0d", m_tx.pwrite, s_tx.pwrite),
        UVM_HIGH);
      apb_master_pwrite_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PWRITE_MISMATCH",
        $sformatf("Master PWRITE = %0d Slave PWRITE = %0d", m_tx.pwrite, s_tx.pwrite));
      apb_master_pwrite_fail[master_idx]++;
    end

    if (m_tx.pstrb == s_tx.pstrb) begin
      `uvm_info(get_type_name(), "APB PSTRB match", UVM_HIGH);
      `uvm_info("SB_PSTRB_MATCH",
        $sformatf("Master PSTRB = %0b Slave PSTRB = %0b", m_tx.pstrb, s_tx.pstrb),
        UVM_HIGH);
      apb_master_pstrb_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PSTRB_MISMATCH",
        $sformatf("Master PSTRB = %0b Slave PSTRB = %0b", m_tx.pstrb, s_tx.pstrb));
      apb_master_pstrb_fail[master_idx]++;
    end

    if (m_tx.pprot == s_tx.pprot) begin
      `uvm_info(get_type_name(), "APB PPROT match", UVM_HIGH);
      `uvm_info("SB_PPROT_MATCH",
        $sformatf("Master PPROT = %0d Slave PPROT = %0d", m_tx.pprot, s_tx.pprot),
        UVM_HIGH);
      apb_master_pprot_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PPROT_MISMATCH",
        $sformatf("Master PPROT = %0d Slave PPROT = %0d", m_tx.pprot, s_tx.pprot));
      apb_master_pprot_fail[master_idx]++;
    end

    `uvm_info(get_type_name(),
      "-- --------------------------------- END OF WRITE COMPARISONS ---------------------------------",
      UVM_NONE)

  end
  else if (m_tx.pwrite == 0) begin
    // READ Transaction Comparison
    `uvm_info(get_type_name(),
      "-- --------------------------------- APB SCOREBOARD COMPARISONS [READ] ---------------------------------",
      UVM_HIGH)

    if (m_tx.paddr == s_tx.paddr) begin
      `uvm_info("SB_PADDR_MATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h", m_tx.paddr, s_tx.paddr),
        UVM_HIGH);
      apb_master_paddr_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PADDR_MISMATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h", m_tx.paddr, s_tx.paddr));
      apb_master_paddr_fail[master_idx]++;
    end

    if (m_tx.pwrite == s_tx.pwrite) begin
      `uvm_info(get_type_name(), "APB PWRITE match", UVM_HIGH);
      apb_master_pwrite_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PWRITE_MISMATCH", "PWRITE mismatch in READ transaction");
      apb_master_pwrite_fail[master_idx]++;
    end

    if (m_tx.prdata == s_tx.prdata) begin
      `uvm_info("SB_PRDATA_MATCH",
        $sformatf("Master PRDATA = 0x%0h Slave PRDATA = 0x%0h", m_tx.prdata, s_tx.prdata),
        UVM_HIGH);
      apb_slave_prdata_pass[slave_idx]++;
    end
    else begin
      `uvm_error("SB_PRDATA_MISMATCH",
        $sformatf("Master PRDATA = 0x%0h Slave PRDATA = 0x%0h", m_tx.prdata, s_tx.prdata));
      apb_slave_prdata_fail[slave_idx]++;
    end

    if (m_tx.pprot == s_tx.pprot) begin
      `uvm_info(get_type_name(), "APB PPROT match", UVM_HIGH);
      apb_master_pprot_pass[master_idx]++;
    end
    else begin
      `uvm_error("SB_PPROT_MISMATCH", "PPROT mismatch in READ transaction");
      apb_master_pprot_fail[master_idx]++;
    end

    `uvm_info(get_type_name(),
      "-- --------------------------------- END OF READ COMPARISONS ---------------------------------",
      UVM_HIGH)

  end

endfunction

function void apb_scoreboard::check_phase(uvm_phase phase);

  // Check if total master and slave transaction counts match
  int total_master_tx = 0;
  int total_slave_tx = 0;

  super.check_phase(phase);
  `uvm_info(get_type_name(),
    "-- --------------------------------- SCOREBOARD CHECK PHASE ---------------------------------",
    UVM_HIGH)


  foreach(apb_master_tx_count[i]) total_master_tx += apb_master_tx_count[i];
  foreach(apb_slave_tx_count[i]) total_slave_tx += apb_slave_tx_count[i];

  if (total_master_tx == total_slave_tx) begin
    `uvm_info(get_type_name(),
      $sformatf("Master and Slave have equal total transactions = %0d", total_master_tx),
      UVM_HIGH);
  end
  else begin
    `uvm_error("SC_CheckPhase",
      $sformatf("Transaction count mismatch! Master: %0d, Slave: %0d", total_master_tx, total_slave_tx));
  end

  `uvm_info(get_type_name(),
    $sformatf("apb_master_tx_count : %0p", apb_master_tx_count),
    UVM_HIGH);
  `uvm_info(get_type_name(),
    $sformatf("apb_slave_tx_count  : %0p", apb_slave_tx_count),
    UVM_HIGH);

  // Check per master comparisons
  for(int m = 0; m < NO_OF_MASTERS; m++) begin
    `uvm_info(get_type_name(), $sformatf("\n--- Master[%0d] Checks ---", m), UVM_LOW)

    if ((apb_master_pwdata_pass[m] != 0) && (apb_master_pwdata_fail[m] == 0)) begin
      `uvm_info(get_type_name(),
        $sformatf("Master[%0d] PWDATA comparisons all passed: %0d", m, apb_master_pwdata_pass[m]),
        UVM_HIGH);
    end
    else if (apb_master_pwdata_fail[m] != 0) begin
      `uvm_error("SC_CheckPhase",
        $sformatf("Master[%0d] PWDATA failed: %0d", m, apb_master_pwdata_fail[m]));
    end

    if ((apb_master_paddr_pass[m] != 0) && (apb_master_paddr_fail[m] == 0)) begin
      `uvm_info(get_type_name(),
        $sformatf("Master[%0d] PADDR comparisons all passed: %0d", m, apb_master_paddr_pass[m]),
        UVM_HIGH);
    end
    else if (apb_master_paddr_fail[m] != 0) begin
      `uvm_error("SC_CheckPhase",
        $sformatf("Master[%0d] PADDR failed: %0d", m, apb_master_paddr_fail[m]));
    end

    if ((apb_master_pwrite_pass[m] != 0) && (apb_master_pwrite_fail[m] == 0)) begin
      `uvm_info(get_type_name(),
        $sformatf("Master[%0d] PWRITE comparisons all passed: %0d", m, apb_master_pwrite_pass[m]),
        UVM_HIGH);
    end
    else if (apb_master_pwrite_fail[m] != 0) begin
      `uvm_error("SC_CheckPhase",
        $sformatf("Master[%0d] PWRITE failed: %0d", m, apb_master_pwrite_fail[m]));
    end

    if ((apb_master_pprot_pass[m] != 0) && (apb_master_pprot_fail[m] == 0)) begin
      `uvm_info(get_type_name(),
        $sformatf("Master[%0d] PPROT comparisons all passed: %0d", m, apb_master_pprot_pass[m]),
        UVM_HIGH);
    end
    else if (apb_master_pprot_fail[m] != 0) begin
      `uvm_error("SC_CheckPhase",
        $sformatf("Master[%0d] PPROT failed: %0d", m, apb_master_pprot_fail[m]));
    end

    if ((apb_master_pstrb_pass[m] != 0) && (apb_master_pstrb_fail[m] == 0)) begin
      `uvm_info(get_type_name(),
        $sformatf("Master[%0d] PSTRB comparisons all passed: %0d", m, apb_master_pstrb_pass[m]),
        UVM_HIGH);
    end
    else if (apb_master_pstrb_fail[m] != 0) begin
      `uvm_error("SC_CheckPhase",
        $sformatf("Master[%0d] PSTRB failed: %0d", m, apb_master_pstrb_fail[m]));
    end
  end

  // Check per slave comparisons
  for (int n = 0; n < NO_OF_SLAVES; n++) begin
    `uvm_info(get_type_name(), $sformatf("\n--- Slave[%0d] Checks ---", n), UVM_LOW)

    if ((apb_slave_prdata_pass[n] != 0) && (apb_slave_prdata_fail[n] == 0)) begin
      `uvm_info(get_type_name(),
        $sformatf("Slave[%0d] PRDATA comparisons all passed: %0d", n, apb_slave_prdata_pass[n]),
        UVM_HIGH);
    end
    else if (apb_slave_prdata_fail[n] != 0) begin
      `uvm_error("SC_CheckPhase",
        $sformatf("Slave[%0d] PRDATA failed: %0d", n, apb_slave_prdata_fail[n]));
    end

   /* if ((apb_slave_pslverr_pass[n] != 0) && (apb_slave_pslverr_fail[n] == 0)) begin
      `uvm_info(get_type_name(),
        $sformatf("Slave[%0d] PSLVERR comparisons all passed: %0d", n, apb_slave_pslverr_pass[n]),
        UVM_HIGH);
    end
    else if (apb_slave_pslverr_fail[n] != 0) begin
      `uvm_error("SC_CheckPhase",
        $sformatf("Slave[%0d] PSLVERR failed: %0d", n, apb_slave_pslverr_fail[n]));
    end */
  end

  // Check if all slave analysis FIFOs are empty
  foreach (apb_slave_analysis_fifo[i]) begin
    if (apb_slave_analysis_fifo[i].size() == 0) begin
      `uvm_info("SC_CheckPhase",
        $sformatf("APB Slave analysis FIFO[%0d] is empty", i),
        UVM_HIGH);
    end
    else begin
      `uvm_error("SC_CheckPhase",
        $sformatf("APB Slave analysis FIFO[%0d] is not empty - size: %0d", i, apb_slave_analysis_fifo[i].size()));
    end
  end

  `uvm_info(get_type_name(),
    "-- --------------------------------- END OF SCOREBOARD CHECK PHASE ---------------------------------",
    UVM_HIGH)

endfunction : check_phase


function void apb_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);

  `uvm_info("scoreboard",
    "-- ------------------------------------------------- Scoreboard Report --------------------------------------------------",
    UVM_HIGH);

  `uvm_info(get_type_name(), "Scoreboard Report Phase is starting", UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of transactions from master: %0p", apb_master_tx_count),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of transactions from slave: %0p", apb_slave_tx_count),
    UVM_HIGH);

  // Report per master statistics
  for (int i = 0; i < NO_OF_MASTERS; i++) begin
    `uvm_info(get_type_name(),
      $sformatf("\n========== Master[%0d] Statistics ==========", i),
      UVM_HIGH);

    `uvm_info(get_type_name(),
      $sformatf("  PWDATA Passed: %0d, Failed: %0d",
                apb_master_pwdata_pass[i], apb_master_pwdata_fail[i]),
      UVM_HIGH);

    `uvm_info(get_type_name(),
      $sformatf("  PADDR Passed: %0d, Failed: %0d",
                apb_master_paddr_pass[i], apb_master_paddr_fail[i]),
      UVM_HIGH);

    `uvm_info(get_type_name(),
      $sformatf("  PWRITE Passed: %0d, Failed: %0d",
                apb_master_pwrite_pass[i], apb_master_pwrite_fail[i]),
      UVM_HIGH);

    `uvm_info(get_type_name(),
      $sformatf("  PPROT Passed: %0d, Failed: %0d",
                apb_master_pprot_pass[i], apb_master_pprot_fail[i]),
      UVM_HIGH);

    `uvm_info(get_type_name(),
      $sformatf("  PSTRB Passed: %0d, Failed: %0d",
                apb_master_pstrb_pass[i], apb_master_pstrb_fail[i]),
      UVM_HIGH);
  end

  // Report per slave statistics
  for (int j = 0; j < NO_OF_SLAVES; j++) begin
    `uvm_info(get_type_name(),
      $sformatf("\n========== Slave[%0d] Statistics ==========", j),
      UVM_HIGH);

    `uvm_info(get_type_name(),
      $sformatf("  PRDATA Passed: %0d, Failed: %0d",
                apb_slave_prdata_pass[j], apb_slave_prdata_fail[j]),
      UVM_HIGH);

    `uvm_info(get_type_name(),
      $sformatf("  PSLVERR Passed: %0d, Failed: %0d",
                apb_slave_pslverr_pass[j], apb_slave_pslverr_fail[j]),
      UVM_HIGH);
  end
endfunction
`endif
