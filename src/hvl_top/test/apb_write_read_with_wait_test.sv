`ifndef APB_WRITE_READ_WITH_WAIT_TEST_INCLUDED_
`define APB_WRITE_READ__WITH_WAIT_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_write_read_with_wait_test
//  Extends the base test and starts the virtual sequence of 8 bit
//--------------------------------------------------------------------------------------------
class apb_write_read_with_wait_test extends apb_base_test;
  `uvm_component_utils(apb_write_read_with_wait_test)
 
  //Variable: apb_virtual_write_read_with_wait_seq_h'
  //Instatiation of apb_virtual_write_read_with_wait_seq
  apb_virtual_write_read_with_wait_seq apb_virtual_write_read_with_wait_seq_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "apb_write_read_with_wait_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : apb_write_read_with_wait_test

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_write_read_with_wait_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function apb_write_read_with_wait_test::new(string name = "apb_write_read_with_wait_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: run_phase
//  Creates the apb_virtual_write_read_with_wait_seq sequnce and starts the 8b virtual sequences
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task apb_write_read_with_wait_test::run_phase(uvm_phase phase);

  apb_virtual_write_read_with_wait_seq_h = apb_virtual_write_read_with_wait_seq::type_id::create("apb_virtual_write_read_with_wait_seq_h");
  phase.raise_objection(this);
    apb_virtual_write_read_with_wait_seq_h.start(apb_env_h.apb_virtual_seqr_h);
   #100;

  phase.drop_objection(this);

endtask : run_phase

`endif
