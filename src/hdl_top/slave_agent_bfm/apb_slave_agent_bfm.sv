`ifndef APB_SLAVE_AGENT_BFM_INCLUDED_
`define APB_SLAVE_AGENT_BFM_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module      : apb_slave Agent BFM
// Description : Instantiates driver and monitor
//--------------------------------------------------------------------------------------------
module apb_slave_agent_bfm #(parameter int SLAVE_ID=0) (apb_if intf);

  //-------------------------------------------------------
  // Importing uvm_pkg file
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  //-------------------------------------------------------
  // slave driver bfm instantiation
  //-------------------------------------------------------
  apb_slave_driver_bfm apb_slave_drv_bfm_h(.pclk(intf.pclk),
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
  // slave monitor bfm instantiation
  //-------------------------------------------------------
  apb_slave_monitor_bfm apb_slave_mon_bfm_h (.pclk(intf.pclk),
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

  initial begin
    uvm_config_db#(virtual apb_slave_driver_bfm)::set(null,"*", $sformatf("apb_slave_driver_bfm_%0d",SLAVE_ID), apb_slave_drv_bfm_h); 
    uvm_config_db #(virtual apb_slave_monitor_bfm)::set(null,"*", $sformatf("apb_slave_monitor_bfm_%0d",SLAVE_ID), apb_slave_mon_bfm_h); 
  end

endmodule : apb_slave_agent_bfm

`endif

