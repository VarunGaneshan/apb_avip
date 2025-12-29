`ifndef APB_VIRTUAL_32B_WRITE_MULTIPLE_SLAVE_SEQ_INCLUDED_
`define APB_VIRTUAL_32B_WRITE_MULTIPLE_SLAVE_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_virtual_32b_write_multiple_slave_seq
//  Creates and starts the master and slave sequences
//--------------------------------------------------------------------------------------------
class apb_virtual_32b_write_multiple_slave_seq extends apb_virtual_base_seq;
  `uvm_object_utils(apb_virtual_32b_write_multiple_slave_seq)

  //Variable: apb_master_32b_write_seq_h
  //Instatiation of apb_master_32b_write_seq
  apb_master_32b_write_seq apb_master_32b_write_seq_h[NO_OF_MASTERS];

  //Variable: apb_slave_32b_write_seq_h
  //Instantiation of apb_slave_32b_write_seq
  apb_slave_32b_write_seq apb_slave_32b_write_seq_h[NO_OF_SLAVES];
  apb_slave_32b_write_seq apb_slave_32b_write_seq_h1[NO_OF_SLAVES];
  
  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------

  extern function new(string name ="apb_virtual_32b_write_multiple_slave_seq");
  extern task body();

endclass : apb_virtual_32b_write_multiple_slave_seq

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_virtual_32b_write_multiple_slave_seq
//--------------------------------------------------------------------------------------------
function apb_virtual_32b_write_multiple_slave_seq::new(string name ="apb_virtual_32b_write_multiple_slave_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task - body
// Creates and starts the 32bit data of master and slave sequences
//--------------------------------------------------------------------------------------------
task apb_virtual_32b_write_multiple_slave_seq::body();
  super.body();
	foreach(apb_master_32b_write_seq_h[i]) begin
  	apb_master_32b_write_seq_h[i]=apb_master_32b_write_seq::type_id::create("apb_master_32b_write_seq_h");
	end
	foreach(apb_slave_32b_write_seq_h[i]) begin
  	apb_slave_32b_write_seq_h[i]=apb_slave_32b_write_seq::type_id::create("apb_slave_32b_write_seq_h");
	end
	foreach(apb_slave_32b_write_seq_h1[i]) begin
	  apb_slave_32b_write_seq_h1[i]=apb_slave_32b_write_seq::type_id::create("apb_slave_32b_write_seq_h1");
	end
  fork
    fork
      //forever begin
        apb_slave_32b_write_seq_h[0].start(p_sequencer.apb_slave_seqr_h[0]);
        apb_slave_32b_write_seq_h1[0].start(p_sequencer.apb_slave_seqr_h[1]);
      //end
    join_any
    //join_none

    fork
      repeat(2) begin
        apb_master_32b_write_seq_h[0].start(p_sequencer.apb_master_seqr_h[0]);
      end
    join
  join
endtask : body

`endif

