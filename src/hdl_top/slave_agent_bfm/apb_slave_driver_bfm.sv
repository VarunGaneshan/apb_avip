`ifndef APB_SLAVE_DRIVER_BFM_INCLUDED_
`define APB_SLAVE_DRIVER_BFM_INCLUDED_

//-------------------------------------------------------
// Importing apb global package
//-------------------------------------------------------
import apb_global_pkg::*;

//--------------------------------------------------------------------------------------------
// Interface : apb_slave_driver_bfm
//  Used as the HDL driver for apb
//  It connects with the HVL driver_proxy for driving the stimulus
//--------------------------------------------------------------------------------------------
interface apb_slave_driver_bfm (input bit pclk,
                               input bit preset_n,
                               input bit psel,
                               input logic penable,
                               input logic [ADDRESS_WIDTH-1:0]paddr,
                               input logic pwrite,
                               input logic [(DATA_WIDTH/8)-1:0]pstrb, 
                               input logic [DATA_WIDTH-1:0]pwdata,
                               output bit pslverr,
                               output bit pready,
                               input bit [2:0]pprot,
                               output logic [DATA_WIDTH-1:0]prdata
                               );

  //-------------------------------------------------------
  // Importing uvm package
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  //-------------------------------------------------------
  // Importing slave driver proxy
  //------------------------------------------------------- 
  import apb_slave_pkg::*;

  //Variable: apb_slave_drv_proxy_h
  //Declaring handle for apb_slave_driver_proxy
  apb_slave_driver_proxy apb_slave_drv_proxy_h;
  
  //Variable : name
  //Used to store the name of the interface
  string name;

  //-------------------------------------------------------
  // Task: wait_for_preset_n
  // Waiting for the system reset to be active low
  //-------------------------------------------------------
  task wait_for_preset_n();

    @(negedge preset_n);
    //`uvm_info(name,$sformatf("SYSTEM RESET DETECTED"),UVM_HIGH)
    @(posedge preset_n);
    //`uvm_info(name,$sformatf("SYSTEM RESET DEACTIVATED"),UVM_HIGH)
  
  endtask: wait_for_preset_n
 
  clocking slaveCb @(posedge pclk);
   default input #1 output #1;
   input preset_n, psel, penable,paddr, pwrite,pstrb,pwdata,pprot;
   output pslverr, pready, prdata;

  endclocking
  


  //-------------------------------------------------------
  // Task: wait_for_setup_state
  // Samples the required data and sends back to the proxy
  //-------------------------------------------------------
  task wait_for_setup_state(output apb_transfer_char_s data_packet, int slave_id);
	  name = $sformatf("APB_SLAVE_DRIVER_BFM_%0d",slave_id);
    @(slaveCb);
   
    slaveCb.pready<=0; 
    `uvm_info(name,$sformatf("SLAVE_ID %0D WAITING FOR SETUP STATE",slave_id),UVM_HIGH)
    `uvm_info(name,$sformatf("PSEL=%0d",psel),UVM_HIGH)
    
    while(slaveCb.psel !==1) begin
      //`uvm_info(name, $sformatf("SLAVE_ID %0d Inside while loop: penable =%0d, pready=%0d, psel=%0d ", slave_id, penable, pready, psel), UVM_HIGH)
      @(slaveCb);
      $display("SLAVE_ID %0d WAITING FOR SELECT psel is %0b",slave_id, slaveCb.psel);
    end

    `uvm_info(name,$sformatf("SLAVE_ID %0d SETUP PHASE STARTED", slave_id),UVM_HIGH)
    `uvm_info(name,$sformatf("PSEL = %0b",psel),UVM_HIGH)
    `uvm_info(name,$sformatf("SLAVE SETUP STATE DONE"),UVM_HIGH)

    // Sampling the signals
    data_packet.psel  = slaveCb.psel;
    data_packet.paddr  = slaveCb.paddr;
    data_packet.pwrite = slaveCb.pwrite;
    if(slaveCb.pwrite == WRITE) begin
      data_packet.pwdata = slaveCb.pwdata;
      data_packet.pstrb  = slaveCb.pstrb;
    end
    data_packet.pprot = slaveCb.pprot;
   
  endtask: wait_for_setup_state

  //-------------------------------------------------------
  // Task: wait_for_access_state
  // Samples the data or drives the data to master based
  // on pwrite signal
  //-------------------------------------------------------
  task wait_for_access_state(inout apb_transfer_char_s data_packet, int slave_id);
    `uvm_info(name,$sformatf("SLAVE_ID %0d WAITING FOR ACCESS STATE - no_of_wait_states=%0d",slave_id, data_packet.no_of_wait_states),UVM_HIGH);

    repeat(data_packet.no_of_wait_states)begin
      `uvm_info(name,$sformatf("SLAVE_ID %0d INSIDE ACCESS - DRIVING WAIT STATE", slave_id),UVM_HIGH);
      @(slaveCb);
      slaveCb.pready<=0;
    end
    slaveCb.pready<=1;

    // This display checks whether the data from proxy is received or not
    `uvm_info(name,$sformatf("INSIDE ACCESS - PRDATA=%0h | pready = %0b",data_packet.prdata, slaveCb.pready),UVM_HIGH);
    
    /*if(data_packet.pwrite == READ) begin
      `uvm_info(name,$sformatf("INSIDE ACCESS - PRDATA=%0h | pready = %0b",data_packet.prdata, slaveCb.pready),UVM_HIGH);
      `uvm_info(name,$sformatf("SLAVE_ID %0d INSIDE ACCESS - PRDATA=%0h",slave_id, data_packet.prdata),UVM_HIGH);
		end 
		*/
    if(data_packet.pwrite == READ) begin
      `uvm_info(name,$sformatf("SLAVE_ID %0d INSIDE ACCESS - PRDATA=%0h",slave_id, data_packet.prdata),UVM_HIGH);
      slaveCb.prdata <= data_packet.prdata;
      @(slaveCb); // if not present will detect the psel even if the transfer is not needed (psel made 0)
      slaveCb.pready <=0; 
    end
    else begin  
      @(slaveCb); 
    slaveCb.pready <= 0;
    end 

    `uvm_info(name,$sformatf("INSIDE ACCESS - PRDATA=%0h | pready = %0b",data_packet.prdata, slaveCb.pready),UVM_HIGH);
    slaveCb.pslverr <= data_packet.pslverr;

  endtask: wait_for_access_state

endinterface : apb_slave_driver_bfm

`endif

