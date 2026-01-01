`ifndef HDL_TOP_INCLUDED
`define HDL_TOP_INCLUDED

//--------------------------------------------------------------------------------------------
// Module      : HDL Top
// Description : Has a interface and slave agent bfm.
//--------------------------------------------------------------------------------------------
module hdl_top;

  //-------------------------------------------------------
  // Importing uvm package and Including uvm macros file
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  //-------------------------------------------------------
  // Importing apb global package
  //-------------------------------------------------------
  import apb_global_pkg::*;

  initial begin
    `uvm_info("HDL_TOP","HDL_TOP",UVM_LOW);
  end

  //Variable : pclk
  //Declaration of system clock
  bit pclk;

  //Variable : preset_n
  //Declaration of system reset
  bit preset_n;

  //-------------------------------------------------------
  // Generation of system clock at frequency rate of 20ns
  //-------------------------------------------------------
  initial begin
    pclk = 1'b0;
    forever #10 pclk =!pclk;
  end

  //-------------------------------------------------------
  // Generation of system preset_n
  //  system reset can be asserted asynchronously,
  //  but system reset de-assertion is synchronous.
  //-------------------------------------------------------
  initial begin
    preset_n = 1'b1;
    #15 preset_n = 1'b0;

    repeat(1) begin
      @(posedge pclk);
    end
    preset_n = 1'b1;
  end

  initial begin
    $dumpfile("waveform.vcd");      // name of the VCD file
    $dumpvars(0,hdl_top);    // dump variables from the testbench top
  end

  //-------------------------------------------------------
  // APB Interfaces Instantiation for Master and Slave agents
  //-------------------------------------------------------
  apb_if intf_s[0:NO_OF_SLAVES-1](pclk,preset_n);
  apb_if intf_m[0:NO_OF_MASTERS-1](pclk,preset_n);

	// Assigining the pclk and preset_n to all interfaces of slave and master
	generate
		for(genvar i = 0; i < NO_OF_SLAVES; i++) begin
			assign intf_s[i].pclk = pclk;
			assign intf_s[i].preset_n = preset_n;
		end
		for(genvar j = 0; j < NO_OF_MASTERS; j++) begin 
			assign intf_m[j].pclk = pclk;
			assign intf_m[j].preset_n = preset_n;
		end
	endgenerate

  //-------------------------------------------------------
  // APB Interconnect Instantiation for Multiple Masters and Slaves
  //-------------------------------------------------------
	//apb_interconnect interconnect(.pclk(pclk), .preset_n(preset_n), .master_if(intf_m), .slave_if(intf_s));

 /* 
  always_comb begin
    case(intf.pselx)
      2'b01: begin
               intf_s[0].pselx   = intf.pselx[0];
               intf_s[0].penable = intf.penable;
               intf_s[0].paddr   = intf.paddr;
               intf_s[0].pwrite  = intf.pwrite;
               intf_s[0].pstrb   = intf.pstrb;
               intf_s[0].pwdata  = intf.pwdata;
               intf_s[0].pprot   = intf.pprot;
               intf.pready  = intf_s[0].pready;
               intf.prdata  = intf_s[0].prdata;
               intf.pslverr = intf_s[0].pslverr;
             end
     //-------------------------------------------------------------------------------------------
     //whenever you require multiple slaves like 2 slave then uncomment below case
     //So if you uncomment then case 1 and case 2 will select particular slave
     //As of now using single slave and connected using case 1
     //Change NO_OF_SLAVES 1 to 2 inside the global pkg then you will get 2 slave interface handle
     //-------------------------------------------------------------------------------------------
     // 2'b10: begin
     //          intf_s[1].pselx = intf.pselx[1];
     //          intf_s[1].penable = intf.penable;
     //          intf_s[1].paddr   = intf.paddr;
     //          intf_s[1].pwrite  = intf.pwrite;
     //          intf_s[1].pstrb   = intf.pstrb;
     //          intf_s[1].pwdata  = intf.pwdata;
     //          intf_s[1].pprot   = intf.pprot;
     //          intf.pready  = intf_s[1].pready;
     //          intf.prdata  = intf_s[1].prdata;
     //          intf.pslverr = intf_s[1].pslverr;
     //        end
      default : begin
                  intf_s[0].pselx   = 'b0;
                  intf_s[0].penable = 'b0;
                  //intf_s[1].pselx   = 'b0;
                  //intf_s[1].penable = 'b0;
                end
    endcase
  end
*/
  //-------------------------------------------------------
  // APB Slave and Master BFM Agent Instantiation
  //-------------------------------------------------------
  genvar j;
  generate 
    for(j = 0; j < NO_OF_MASTERS; j++) begin : apb_master_agent_bfm
      apb_master_agent_bfm #(.MASTER_ID(j)) apb_master_agent_bfm_h(.intf(intf_m[j].apbMasterInterconnectMP));
      defparam apb_master_agent_bfm[j].apb_master_agent_bfm_h.MASTER_ID = j;
    end
  endgenerate

  genvar i;
  generate
    for(i = 0; i < NO_OF_SLAVES; i++) begin : apb_slave_agent_bfm
      apb_slave_agent_bfm #(.SLAVE_ID(i)) apb_slave_agent_bfm_h(.intf(intf_s[i].apbSlaveInterconnectMP));
      defparam apb_slave_agent_bfm[i].apb_slave_agent_bfm_h.SLAVE_ID = i;
    end
  endgenerate

endmodule : hdl_top

`endif

