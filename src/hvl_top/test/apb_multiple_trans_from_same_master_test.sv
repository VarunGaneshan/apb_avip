`ifndef APB_MULTIPLE_TRANS_FROM_SAME_MASTER_TEST_INCLUDED_
`define APB_MULTIPLE_TRANS_FROM_SAME_MASTER_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_multiple_trans_from_same_master_test
//  Extends the base test and starts the virtual sequence of 8 bit
//--------------------------------------------------------------------------------------------
class apb_multiple_trans_from_same_master_test extends apb_base_test;
  `uvm_component_utils(apb_multiple_trans_from_same_master_test)
 
  //Variable: apb_virtual_multiple_trans_from_same_master_seq_h'
  //Instatiation of apb_virtual_multiple_trans_from_same_master_seq
  apb_virtual_multiple_trans_from_same_master_seq apb_virtual_multiple_trans_from_same_master_seq_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "apb_multiple_trans_from_same_master_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : apb_multiple_trans_from_same_master_test

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_multiple_trans_from_same_master_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function apb_multiple_trans_from_same_master_test::new(string name = "apb_multiple_trans_from_same_master_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: run_phase
//  Creates the apb_virtual_multiple_trans_from_same_master_seq sequnce and starts the 8b virtual sequences
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task apb_multiple_trans_from_same_master_test::run_phase(uvm_phase phase);

  apb_virtual_multiple_trans_from_same_master_seq_h = apb_virtual_multiple_trans_from_same_master_seq::type_id::create("apb_virtual_multiple_trans_from_same_master_seq_h");
  phase.raise_objection(this);
    apb_virtual_multiple_trans_from_same_master_seq_h.start(apb_env_h.apb_virtual_seqr_h);
   #100;

  phase.drop_objection(this);

endtask : run_phase

`endif
