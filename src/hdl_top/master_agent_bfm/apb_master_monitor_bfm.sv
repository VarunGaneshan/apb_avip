`ifndef APB_MASTER_MONITOR_BFM_INCLUDED_
`define APB_MASTER_MONITOR_BFM_INCLUDED_

//-------------------------------------------------------
// Importing apb global package
//-------------------------------------------------------
import apb_global_pkg::*;

//--------------------------------------------------------------------------------------------
// Interface: apb_master_monitor_bfm
//  Connects the master monitor bfm with the master monitor proxy
//--------------------------------------------------------------------------------------------
interface apb_master_monitor_bfm (input bit pclk,
                                  input bit preset_n,
                                  input bit pslverr,
                                  input bit pready,
                                  input bit [2:0]pprot,
                                  input logic penable,
                                  input logic pwrite,
                                  input logic [ADDRESS_WIDTH-1:0]paddr,
                                  input logic [NO_OF_SLAVES-1:0]psel,
                                  input logic [DATA_WIDTH-1:0]pwdata,
                                  input logic [(DATA_WIDTH/8)-1:0]pstrb, 
                                  input logic [DATA_WIDTH-1:0]prdata
                                 );

  //-------------------------------------------------------
  // Importing uvm package and apb_master_pkg file
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //-------------------------------------------------------
  // Importing global package
  //-------------------------------------------------------
  import apb_master_pkg::*;

  // Variable: apb_master_mon_proxy_h
  // Declaring handle for apb_master_monitor_proxy  
  apb_master_monitor_proxy apb_master_mon_proxy_h;

  // Variable: name
  // Assigning the string used in infos
  string name = "APB_MASTER_MONITOR_BFM"; 
 
  initial begin
    `uvm_info(name, $sformatf("APB MASTER MONITOR BFM"), UVM_LOW);
  end

  //-------------------------------------------------------
  // Task: wait_for_preset_n
  //  Waiting for the system reset to be active low
  //-------------------------------------------------------
  task wait_for_preset_n();
    @(negedge preset_n);
    `uvm_info(name, $sformatf("system reset detected"), UVM_HIGH)
    
    @(posedge preset_n);
    `uvm_info(name, $sformatf("system reset deactivated"), UVM_HIGH)
  endtask : wait_for_preset_n
  
  //-------------------------------------------------------
  // Task: sample_data
  //  In this task, the pwdata and prdata is sampled
  //
  // Parameters: 
  //  apb_data_packet - Handle for apb_transfer_char_s class
  //  apb_cfg_packet  - Handle for apb_transfer_cfg_s class
  //-------------------------------------------------------
  task sample_data (output apb_transfer_char_s apb_data_packet, input apb_transfer_cfg_s apb_cfg_packet);
    @(posedge pclk);
    
     while(psel !== 1) begin
      `uvm_info(name, $sformatf("Inside while loop: penable =%0d, pready=%0d, psel=%0d", penable, pready, psel), UVM_HIGH)
      @(posedge pclk);
      $display("SET UP STATE ");
    end

   $display("SET UP STATE CAPTURED @%0T",$time());
    apb_data_packet.pslverr = pslverr;
    apb_data_packet.pprot   = pprot;
    $display("MASTER MON WRITE IS %0d",pwrite);
    apb_data_packet.pwrite  = pwrite;
    apb_data_packet.paddr   = paddr;
    apb_data_packet.psel   = psel;
    apb_data_packet.pstrb   = pstrb;

    if (pwrite == WRITE) begin
      apb_data_packet.pwdata = pwdata;
    end
    `uvm_info(name, $sformatf("\n\n\nMASTER_SAMPLE_DATA=%p\n\n\n", apb_data_packet), UVM_MEDIUM)
  endtask : sample_data

task access_state(output apb_transfer_char_s apb_data_packet, input apb_transfer_cfg_s apb_cfg_packet);
@(posedge pclk);
  while(pready !== 1) begin
      $display("ACCESS SATTE");
      `uvm_info(name, $sformatf("Inside while loop: penable =%0d, pready=%0d, psel=%0d", penable, pready, psel), UVM_HIGH)
      @(posedge pclk);
      //Increment the counter of wait states
      apb_data_packet.no_of_wait_states++;
    end
  apb_data_packet.pready = pready;
  $display("$$$$$$$$$$$$$$$$$$$$$BFM PENABLE IS %0b %0t$$$$$$$$$$$$$$$$$",penable,$time());
  apb_data_packet.penable = penable;
endtask


endinterface : apb_master_monitor_bfm

`endif

