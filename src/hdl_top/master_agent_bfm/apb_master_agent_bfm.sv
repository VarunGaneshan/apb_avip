`ifndef APB_MASTER_AGENT_BFM_INCLUDED_
`define APB_MASTER_AGENT_BFM_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module      : APB Master Agent BFM
// Description : Instantiates driver and monitor
//--------------------------------------------------------------------------------------------
module apb_master_agent_bfm #(parameter MASTER_ID = 0)(apb_if intf);

  //-------------------------------------------------------
  // Importing uvm package file
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
	localparam apb_master_driver_id  = MASTER_ID;
	localparam apb_master_monitor_id = MASTER_ID;
	localparam apb_master_agent_id   = MASTER_ID;

  initial begin
    `uvm_info("apb master agent bfm",$sformatf("APB MASTER AGENT BFM"),UVM_LOW);
  end
  
  //-------------------------------------------------------
  // master driver bfm instantiation
  //-------------------------------------------------------
  apb_master_driver_bfm apb_master_drv_bfm_h (.pclk(intf.pclk),
                                              .preset_n(intf.preset_n),
                                              .psel(intf.psel),
                                              .penable(intf.penable),
                                              .pprot(intf.pprot),
                                              .paddr(intf.paddr),
                                              .pwrite(intf.pwrite),
                                              .pwdata(intf.pwdata),
                                              .pstrb(intf.pstrb),
                                              .pslverr(intf.pslverr),
                                              .pready(intf.pready),
                                              .prdata(intf.prdata)
                                              );

  //-------------------------------------------------------
  // master monitor bfm instantiation
  //-------------------------------------------------------
  apb_master_monitor_bfm apb_master_mon_bfm_h (.pclk(intf.pclk),
                                              .preset_n(intf.preset_n),
                                              .psel(intf.psel),
                                              .paddr(intf.paddr),
                                              .pwrite(intf.pwrite),
                                              .pwdata(intf.pwdata),
                                              .pstrb(intf.pstrb),
                                              .pslverr(intf.pslverr),
                                              .pready(intf.pready),
                                              .prdata(intf.prdata),
                                              .penable(intf.penable),
                                              .pprot(intf.pprot)
                                              );


  //-------------------------------------------------------
  // setting the virtual handle of BFMs into config_db
  //-------------------------------------------------------
  initial begin
		uvm_config_db#(virtual apb_master_driver_bfm)::set(null,"*",$sformatf("apb_master_driver_bfm_%0d",apb_master_driver_id),apb_master_drv_bfm_h);
    uvm_config_db#(virtual apb_master_monitor_bfm)::set(null,"*",$sformatf("apb_master_monitor_bfm_%0d",apb_master_monitor_id),apb_master_mon_bfm_h);
	end

endmodule : apb_master_agent_bfm

`endif

