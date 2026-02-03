`ifndef APB_MASTER_SEQ_PKG_INCLUDED_
`define APB_MASTER_SEQ_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package : apb_master_seq_pkg
//  Includes all the master seq files declared
//--------------------------------------------------------------------------------------------
package apb_master_seq_pkg;

  //-------------------------------------------------------
  // Importing UVM Pkg and including globall and master packages
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_global_pkg::*;
  import apb_master_pkg::*;

  //-------------------------------------------------------
  // Including required apb master seq files
  //-------------------------------------------------------
  `include "apb_master_base_seq.sv"
  `include "apb_master_sequence.sv"

endpackage : apb_master_seq_pkg

`endif

