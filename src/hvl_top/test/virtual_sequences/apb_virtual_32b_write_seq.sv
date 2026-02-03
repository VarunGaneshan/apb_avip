`ifndef APB_VIRTUAL_32B_WRITE_SEQ_INCLUDED_
`define APB_VIRTUAL_32B_WRITE_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_virtual_32b_write_seq
// Creates and starts the master and slave vd_vws sequnences of variable data and variable 
// wait states.
//--------------------------------------------------------------------------------------------
class apb_virtual_32b_write_seq extends apb_virtual_base_seq;
  `uvm_object_utils(apb_virtual_32b_write_seq)

  //Variable: apb_master_32b_seq_h
  //Instatiation of apb_master_32b_write_seq
  apb_master_sequence apb_master_32b_write_seq_h[NO_OF_MASTERS];

  //Variable: apb_slave_32b_write_seq_h
  //Instantiation of apb_master_32b_write_seq
  apb_slave_sequence apb_slave_32b_write_seq_h[TOTAL_SLAVES];

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------

  extern function new(string name ="apb_virtual_32b_write_seq");
  extern task body();

endclass : apb_virtual_32b_write_seq
//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_virtual_32b_write_seq
//--------------------------------------------------------------------------------------------

function apb_virtual_32b_write_seq::new(string name ="apb_virtual_32b_write_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task - body
// Creates and starts the 32bit data of master and slave sequences
//--------------------------------------------------------------------------------------------
task apb_virtual_32b_write_seq::body();
  super.body();
  
  foreach(apb_master_32b_write_seq_h[i]) begin
    apb_master_32b_write_seq_h[i] = apb_master_sequence::type_id::create($sformatf("apb_master_32b_write_seq_h[%0d]", i));
  end

  foreach(apb_slave_32b_write_seq_h[i]) begin
    apb_slave_32b_write_seq_h[i] = apb_slave_sequence::type_id::create($sformatf("apb_slave_32b_write_seq_h[%0d]", i));
  end

  foreach(apb_slave_32b_write_seq_h[i]) begin
    fork
      automatic int j = i;
      forever begin
        apb_slave_32b_write_seq_h[j].start(p_sequencer.apb_slave_seqr_h[j]);
      end
    join_none
  end

  fork
    begin
      foreach(apb_master_32b_write_seq_h[i]) begin
				if(!apb_master_32b_write_seq_h[i].randomize() with { address_seq inside {[master_addr.min_addr[i]:master_addr.max_addr[i]]};}) begin
          `uvm_error(get_type_name(), $sformatf("Randomization failed for master %0d", i))
        end
      end
      
      fork
        foreach(apb_master_32b_write_seq_h[i]) begin
          automatic int idx = i;
          apb_master_32b_write_seq_h[idx].start(p_sequencer.apb_master_seqr_h[idx]);
        end
      join_none
      
      wait fork;
    end
  join

endtask : body

`endif
