`ifndef APB_MASTER_SEQUENCE_INCLUDED_
`define APB_MASTER_SEQUENCE_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_master_sequence
// Extends the apb_master_base_seq and randomises the req item
//--------------------------------------------------------------------------------------------
class apb_master_sequence extends apb_master_base_seq;
  `uvm_object_utils(apb_master_sequence)

	rand bit [ADDRESS_WIDTH-1:0] address;
  rand int wait_states;
	rand transfer_size_e transfer_len;
  rand tx_type_e read_write; 

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "apb_master_sequence");
  extern task body();

	constraint default_values {
    soft read_write == WRITE;
		soft wait_states == 0;
		soft transfer_len == BIT_8;
	}

endclass : apb_master_sequence

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_master_sequence
//--------------------------------------------------------------------------------------------
function apb_master_sequence::new(string name = "apb_master_sequence");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: body
//  Creates the req of type master transaction and randomises the req.
//--------------------------------------------------------------------------------------------
task apb_master_sequence::body();
  super.body();
  req=apb_master_tx::type_id::create("req");
  req.apb_master_agent_cfg_h = p_sequencer.apb_master_agent_cfg_h;
  start_item(req);
  	
  if(!req.randomize() with {
					                  req.no_of_wait_states_detected == wait_states;
				                    req.paddr == address;	
                            req.transfer_size == transfer_len;
                            req.pwrite == read_write;}) begin
    `uvm_fatal("APB","Rand failed");
  end
  finish_item(req);

endtask : body

`endif
