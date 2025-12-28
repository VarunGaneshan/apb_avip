`ifndef APB_SCOREBOARD_INCLUDED_
`define APB_SCOREBOARD_INCLUDED_

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_tlm_analysis_fifo #(apb_master_tx) apb_master_analysis_fifo[];
  uvm_tlm_analysis_fifo #(apb_slave_tx)  apb_slave_analysis_fifo[];

  int apb_master_tx_count = 0;
  int apb_slave_tx_count = 0;

  int apb_master_pwdata_pass = 0;
  int apb_master_pwdata_fail = 0;
  int apb_master_paddr_pass = 0; 
  int apb_master_paddr_fail = 0;
  int apb_master_pwrite_pass = 0; 
  int apb_master_pwrite_fail = 0;
  int apb_master_prdata_pass = 0;
  int apb_master_prdata_fail = 0;
  int apb_master_pprot_pass = 0;  
  int apb_master_pprot_fail = 0;
  int apb_master_pstrb_pass = 0;  
  int apb_master_pstrb_fail = 0;

  int match_found_count = 0;
  int match_fail_count = 0;

  // Expected Queues: One queue per slave to store predicted transactions
  apb_master_tx slave_expected_q[int][$];

  extern function new(string name="apb_scoreboard", uvm_component parent=null);
  extern function void build_phase(uvm_phase phase);
  extern function int get_slave_index(bit [31:0] addr);
  extern task run_phase(uvm_phase phase);
  extern function void compare_trans(apb_master_tx m_tx, apb_slave_tx s_tx);
  extern function void check_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);
  
endclass

function apb_scoreboard::new(string name="apb_scoreboard", uvm_component parent=null);
  super.new(name, parent);

  apb_master_analysis_fifo = new[NO_OF_MASTERS];
  apb_slave_analysis_fifo = new[NO_OF_SLAVES];
  
  foreach (apb_master_analysis_fifo[i]) begin
    apb_master_analysis_fifo[i] = new($sformatf("apb_master_analysis_fifo[%0d]", i), this);
  end

  foreach (apb_slave_analysis_fifo[i]) begin
    apb_slave_analysis_fifo[i] = new($sformatf("apb_slave_analysis_fifo[%0d]", i), this);
  end
endfunction

function void apb_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction

task apb_scoreboard::run_phase(uvm_phase phase);
  super.run_phase(phase);

  // seperates every master and slave making each thread for those
   foreach(apb_master_analysis_fifo[i]) begin
     automatic int master_idx = i;
   fork 
    forever begin
      // write a display statement before the get inorder to see if the simulation gets stuck
      apb_master_tx m_tx;
      int slave_idx;
      apb_master_analysis_fifo[master_idx].get(m_tx);
      apb_master_tx_count++;

      // routing information to check which slave its accessing 
      slave_idx = get_slave_index(m_tx.paddr);

      if(slave_idx == -1) begin
             `uvm_error("SCB", $sformatf("Address 0x%0h does not map to any valid slave", m_tx.paddr))
          end else begin
             // Push into the specific slave's expected queue
             slave_expected_q[slave_idx].push_back(m_tx);
             `uvm_info("SCB", $sformatf("Master[%0d] sent TX to Slave[%0d]", master_idx, slave_idx), UVM_MEDIUM)
          end
        end
      join_none
    end
    // get the slave transactions from the fifo for each slave using fork join for each slave
    foreach(apb_slave_analysis_fifo[i]) begin
      automatic int s_index = i;
      fork
        forever begin
          apb_slave_tx s_tx;
          apb_master_tx exp_tx;

          // Get transaction from Slave
          apb_slave_analysis_fifo[s_index].get(s_tx);
          apb_slave_tx_count++;

          // CHECK: Do we have an expected transaction for this slave?
          if(slave_expected_q[s_index].size() == 0) begin
             `uvm_error("SCB", $sformatf("Slave[%0d] received unexpected transaction!", s_index))
             match_fail_count++;
          end else begin
             // Pop the oldest expected transaction
             exp_tx = slave_expected_q[s_index].pop_front();
             // Compare
             compare_trans(exp_tx, s_tx);
          end
        end
      join_none
    end 

    //wait for all the threads to complete 
    wait fork;
endtask
 
//to get the specific slave IDs /customize this based on your design spec
//customize this based on your design spec
function int apb_scoreboard::get_slave_index(bit [31:0] addr);
    if (addr >= 0 && addr < 'h100) return 0;
    if (addr >= 'h100 && addr < 'h200) return 1;
    if (addr >= 'h200 && addr < 'h300) return 2;
    // Add logic for all slaves
    return 0; // Default or return -1 for error
endfunction

function void apb_scoreboard::compare_trans(apb_master_tx m_tx, apb_slave_tx s_tx);
 
  if (m_tx.pwrite == 1 && s_tx.pready == 1) begin
    if (m_tx.psel && m_tx.penable) begin

    `uvm_info(get_type_name(),
      "-- -------------------------------------- APB SCOREBOARD COMPARISONS --------------------------------------",
      UVM_HIGH)

      if (m_tx.pwdata == s_tx.pwdata) begin
        `uvm_info(get_type_name(), "APB PWDATA match", UVM_HIGH);
        `uvm_info("SB_PWDATA_MATCH",
          $sformatf("Master PWDATA = 0x%0h Slave PWDATA = 0x%0h",
                  m_tx.pwdata, s_tx.pwdata),
          UVM_HIGH);
        apb_master_pwdata_pass++;
      end
      else begin
        `uvm_info(get_type_name(), "APB PWDATA mismatch", UVM_HIGH);
        `uvm_error("SB_PWDATA_MISMATCH",
        $sformatf("Master PWDATA = 0x%0h Slave PWDATA = 0x%0h",
                  m_tx.pwdata, s_tx.pwdata));
        apb_master_pwdata_fail++;
      end

      if (m_tx.paddr == s_tx.paddr) begin
        `uvm_info(get_type_name(), "APB PADDR match", UVM_HIGH);
        `uvm_info("SB_PADDR_MATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h",
                  m_tx.paddr, s_tx.paddr),
        UVM_HIGH);
        apb_master_paddr_pass++;
      end
      else begin
        `uvm_info(get_type_name(), "APB PADDR mismatch", UVM_HIGH);
        `uvm_error("SB_PADDR_MISMATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h",
                  m_tx.paddr, s_tx.paddr));
        apb_master_paddr_fail++;
      end

      if (m_tx.pwrite == s_tx.pwrite) begin
        `uvm_info(get_type_name(), "APB PWRITE match", UVM_HIGH);
        `uvm_info("SB_PWRITE_MATCH",
        $sformatf("Master PWRITE = %0d Slave PWRITE = %0d",
                  m_tx.pwrite, s_tx.pwrite),
        UVM_HIGH);
        apb_master_pwrite_pass++;
      end
      else begin
        `uvm_info(get_type_name(), "APB PWRITE mismatch", UVM_HIGH);
        `uvm_error("SB_PWRITE_MISMATCH",
        $sformatf("Master PWRITE = %0d Slave PWRITE = %0d",
                  m_tx.pwrite, s_tx.pwrite));
        apb_master_pwrite_fail++;
      end

      if (m_tx.pstrb == s_tx.pstrb) begin
        `uvm_info(get_type_name(), "APB PSTRB match", UVM_HIGH);
        `uvm_info("SB_PSTRB_MATCH",
        $sformatf("Master PSTRB = %0b Slave PSTRB = %0b",
                  m_tx.pstrb, s_tx.pstrb),
        UVM_HIGH);
        apb_master_pstrb_pass++;
      end
      else begin
        `uvm_info(get_type_name(), "APB PSTRB mismatch", UVM_HIGH);
        `uvm_error("SB_PSTRB_MISMATCH",
        $sformatf("Master PSTRB = %0b Slave PSTRB = %0b",
                  m_tx.pstrb, s_tx.pstrb));
        apb_master_pstrb_fail++;
      end

      if (m_tx.pprot == s_tx.pprot) begin
        `uvm_info(get_type_name(), "APB PPROT match", UVM_HIGH);
        `uvm_info("SB_PPROT_MATCH",
        $sformatf("Master PPROT = %0d Slave PPROT = %0d",
                  m_tx.pprot, s_tx.pprot),
        UVM_HIGH);
        apb_master_pprot_pass++;
      end
      else begin
        `uvm_info(get_type_name(), "APB PPROT mismatch", UVM_HIGH);
        `uvm_error("SB_PPROT_MISMATCH",
        $sformatf("Master PPROT = %0d Slave PPROT = %0d",
                  m_tx.pprot, s_tx.pprot));
        apb_master_pprot_fail++;
      end

    `uvm_info(get_type_name(),
      "-- ------------------------------------ END OF APB SCOREBOARD COMPARISONS ------------------------------------",
      UVM_HIGH)
  end
end

else if (m_tx.pwrite == 0 && s_tx.pready == 1) begin
  if (m_tx.psel && m_tx.penable) begin

    `uvm_info(get_type_name(),
      "-- -------------------------------------- APB SCOREBOARD COMPARISONS --------------------------------------",
      UVM_HIGH)

    if (m_tx.paddr == s_tx.paddr) begin
      `uvm_info("SB_PADDR_MATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h",
                  m_tx.paddr, s_tx.paddr),
        UVM_HIGH);
      apb_master_paddr_pass++;
    end
    else begin
      `uvm_error("SB_PADDR_MISMATCH",
        $sformatf("Master PADDR = 0x%0h Slave PADDR = 0x%0h",
                  m_tx.paddr, s_tx.paddr));
      apb_master_paddr_fail++;
    end

    if (m_tx.pwrite == s_tx.pwrite) begin
      apb_master_pwrite_pass++;
    end
    else begin
      apb_master_pwrite_fail++;
      `uvm_error("SB_PWRITE_MISMATCH", "PWRITE mismatch in READ transaction");
    end

    if (m_tx.prdata == s_tx.prdata) begin
      `uvm_info("SB_PRDATA_MATCH",
        $sformatf("Master PRDATA = 0x%0h Slave PRDATA = 0x%0h",
                  m_tx.prdata, s_tx.prdata),
        UVM_HIGH);
      apb_master_prdata_pass++;
    end
    else begin
      `uvm_error("SB_PRDATA_MISMATCH",
        $sformatf("Master PRDATA = 0x%0h Slave PRDATA = 0x%0h",
                  m_tx.prdata, s_tx.prdata));
      apb_master_prdata_fail++;
    end

    if (m_tx.pprot == s_tx.pprot) begin
      apb_master_pprot_pass++;
    end
    else begin
      apb_master_pprot_fail++;
      `uvm_error("SB_PPROT_MISMATCH", "PPROT mismatch in READ transaction");
    end

    `uvm_info(get_type_name(),
      "-- ------------------------------------ END OF APB SCOREBOARD COMPARISONS ------------------------------------",
      UVM_HIGH)
  end
end
  
endfunction

function void apb_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);

  `uvm_info(get_type_name(),
    "--\n----------------------------------------------SCOREBOARD CHECK PHASE---------------------------------------",
    UVM_HIGH)
  `uvm_info(get_type_name(), "Scoreboard Check Phase is starting", UVM_HIGH);

  if (apb_master_tx_count == apb_slave_tx_count) begin
    `uvm_info(get_type_name(),
      $sformatf("master and slave have equal no. of transactions = %0d",
                apb_master_tx_count),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_master_tx_count : %0d", apb_master_tx_count),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_slave_tx_count  : %0d", apb_slave_tx_count),
      UVM_HIGH);
  end
  else begin
    `uvm_info(get_type_name(),
      $sformatf("apb_master_tx_count : %0d", apb_master_tx_count),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_slave_tx_count  : %0d", apb_slave_tx_count),
      UVM_HIGH);
    `uvm_error("SC_CheckPhase",
      "master and slave does not have same no. of transactions");
  end

  if ((apb_master_pwdata_pass != 0) && (apb_master_pwdata_fail == 0)) begin
    `uvm_info(get_type_name(),
      $sformatf("master and slave pwdata comparisons are equal = %0d",
                apb_master_pwdata_pass),
      UVM_HIGH);
  end
  else begin
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pwdata_pass : %0d", apb_master_pwdata_pass),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pwdata_fail : %0d", apb_master_pwdata_fail),
      UVM_HIGH);
    `uvm_error("SC_CheckPhase",
      "master and slave pwdata comparisons not equal");
  end

  if ((apb_master_prdata_pass != 0) && (apb_master_prdata_fail == 0)) begin
    `uvm_info(get_type_name(),
      $sformatf("master and slave prdata comparisons are equal = %0d",
                apb_master_prdata_pass),
      UVM_HIGH);
  end
  else begin
    `uvm_info(get_type_name(),
      $sformatf("apb_master_prdata_pass : %0d", apb_master_prdata_pass),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_master_prdata_fail : %0d", apb_master_prdata_fail),
      UVM_HIGH);
    `uvm_error("SC_CheckPhase",
      "master and slave prdata comparisons not equal");
  end

  if ((apb_master_paddr_pass != 0) && (apb_master_paddr_fail == 0)) begin
    `uvm_info(get_type_name(),
      $sformatf("master and slave paddr comparisons are equal = %0d",
                apb_master_paddr_pass),
      UVM_HIGH);
  end
  else begin
    `uvm_info(get_type_name(),
      $sformatf("apb_master_paddr_pass : %0d", apb_master_paddr_pass),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_master_paddr_fail : %0d", apb_master_paddr_fail),
      UVM_HIGH);
    `uvm_error("SC_CheckPhase",
      "master and slave paddr comparisons not equal");
  end

  if ((apb_master_pwrite_pass != 0) && (apb_master_pwrite_fail == 0)) begin
    `uvm_info(get_type_name(),
      $sformatf("master and slave pwrite comparisons are equal = %0d",
                apb_master_pwrite_pass),
      UVM_HIGH);
  end
  else begin
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pwrite_pass : %0d", apb_master_pwrite_pass),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pwrite_fail : %0d", apb_master_pwrite_fail),
      UVM_HIGH);
    `uvm_error("SC_CheckPhase",
      "master and slave pwrite comparisons not equal");
  end

  if ((apb_master_pprot_pass != 0) && (apb_master_pprot_fail == 0)) begin
    `uvm_info(get_type_name(),
      $sformatf("master and slave pprot comparisons are equal = %0d",
                apb_master_pprot_pass),
      UVM_HIGH);
  end
  else begin
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pprot_pass : %0d", apb_master_pprot_pass),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pprot_fail : %0d", apb_master_pprot_fail),
      UVM_HIGH);
    `uvm_error("SC_CheckPhase",
      "master and slave pprot comparisons not equal");
  end

  if ((apb_master_pstrb_pass != 0) && (apb_master_pstrb_fail == 0)) begin
    `uvm_info(get_type_name(),
      $sformatf("master and slave pstrb comparisons are equal = %0d",
                apb_master_pstrb_pass),
      UVM_HIGH);
  end
  else begin
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pstrb_pass : %0d", apb_master_pstrb_pass),
      UVM_HIGH);
    `uvm_info(get_type_name(),
      $sformatf("apb_master_pstrb_fail : %0d", apb_master_pstrb_fail),
      UVM_HIGH);
    `uvm_error("SC_CheckPhase",
      "master and slave pstrb comparisons not equal");
  end

  foreach (apb_slave_analysis_fifo[i]) begin
    if (apb_slave_analysis_fifo[i].size() == 0) begin
      `uvm_info("SC_CheckPhase",
        $sformatf("APB Slave analysis FIFO[%0d] is empty", i),
        UVM_HIGH);
    end
    else begin
      `uvm_info(get_type_name(),
        $sformatf("apb_slave_analysis_fifo[%0d] : %0d",
                  i, apb_slave_analysis_fifo[i].size()),
        UVM_HIGH);
      `uvm_error("SC_CheckPhase",
        "APB Slave analysis FIFO is not empty");
    end
  end

  `uvm_info(get_type_name(),
    "--\n----------------------------------------------END OF SCOREBOARD CHECK PHASE---------------------------------------",
    UVM_HIGH)

endfunction : check_phase


function void apb_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);

  `uvm_info("scoreboard",
    $sformatf("--\n--------------------------------------------------Scoreboard Report-----------------------------------------------"),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf(" Scoreboard Report Phase is starting"),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of transactions from master:%0d",
              apb_master_tx_count),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of transactions from slave:%0d",
              apb_slave_tx_count),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("Total no. of byte wise master_pwdata comparisions passed:%0d",
              apb_master_pwdata_pass),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("Total no. of byte wise master_paddr comparisions passed:%0d",
              apb_master_paddr_pass),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("Total no. of byte wise master_pwrite comparisions passed:%0d",
              apb_master_pwrite_pass),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("Total no. of byte wise master_prdata comparisions passed:%0d",
              apb_master_prdata_pass),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("Total no. of byte wise master_pprot comparisions passed:%0d",
              apb_master_pprot_pass),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("Total no. of byte wise master_pstrb comparisions passed:%0d",
              apb_master_pstrb_pass),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of byte wise master_pwdata comparision failed:%0d",
              apb_master_pwdata_fail),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of byte wise master_paddr comparision failed:%0d",
              apb_master_paddr_fail),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of byte wise master_pwrite comparision failed:%0d",
              apb_master_pwrite_fail),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of byte wise master_prdata comparision failed:%0d",
              apb_master_prdata_fail),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of byte wise master_pprot comparision failed:%0d",
              apb_master_pprot_fail),
    UVM_HIGH);

  `uvm_info(get_type_name(),
    $sformatf("No. of byte wise master_pstrb comparision failed:%0d",
              apb_master_pstrb_fail),
    UVM_HIGH);

  `uvm_info("scoreboard",
    $sformatf("--\n--------------------------------------------------End of Scoreboard Report-----------------------------------------------"),
    UVM_HIGH);

endfunction : report_phase

`endif
