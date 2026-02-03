`ifndef APB_SLAVE_SEQ_PKG_INCLUDED_
`define APB_SLAVE_SEQ_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package : apb_slave_seq_pkg
//  Includes all the slave seq files declared
//--------------------------------------------------------------------------------------------
package apb_slave_seq_pkg;

  //-------------------------------------------------------
  // Importing UVM, slave, global package 
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_slave_pkg::*;
  import apb_global_pkg::*;

  //-------------------------------------------------------
  // Including required apb slave seq files
  //-------------------------------------------------------
  `include "apb_slave_base_seq.sv"
  `include "apb_slave_sequence.sv"

endpackage : apb_slave_seq_pkg

`endif

