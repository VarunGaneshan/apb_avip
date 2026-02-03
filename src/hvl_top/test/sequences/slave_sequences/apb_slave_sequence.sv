`ifndef APB_SLAVE_SEQUENCE_INCLUDED_
`define APB_SLAVE_SEQUENCE_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_slave_sequence
//  Extends the apb_slave_base_seq and randomises the req item
//--------------------------------------------------------------------------------------------
class apb_slave_sequence extends apb_slave_base_seq;
  `uvm_object_utils(apb_slave_sequence)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name="apb_slave_sequence");
  extern task body();
endclass : apb_slave_sequence

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_slave_vd_vws
//--------------------------------------------------------------------------------------------
function apb_slave_sequence::new(string name="apb_slave_sequence");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task : Body
//  Creates the req of type slave transaction and randomises the req.
//--------------------------------------------------------------------------------------------
task apb_slave_sequence::body();
  req = apb_slave_tx::type_id::create("req");
  start_item(req);
	if(!req.randomize())
		`uvm_fatal("APB","Rand failed");
  finish_item(req);
endtask : body

`endif
