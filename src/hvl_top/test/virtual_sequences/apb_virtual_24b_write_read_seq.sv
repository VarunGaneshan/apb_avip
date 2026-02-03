`ifndef APB_VIRTUAL_24B_WRITE_READ_SEQ_INCLUDED_
`define APB_VIRTUAL_24B_WRITE_READ_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_virtual_24b_write_read_seq
//  Creates and starts the master and slave sequences
//--------------------------------------------------------------------------------------------
class apb_virtual_24b_write_read_seq extends apb_virtual_base_seq;
  `uvm_object_utils(apb_virtual_24b_write_read_seq)

  //Variable: apb_master_24b_seq_h
  //Instatiation of apb_master_24b_write_seq
  apb_master_sequence apb_master_24b_write_seq_h[NO_OF_MASTERS], apb_master_24b_read_seq_h[NO_OF_MASTERS];

  //Variable: apb_slave_24b_write_seq_h
  //Instatiation of apb_slave_24b_write_seq
  apb_slave_sequence apb_slave_24b_write_seq_h[TOTAL_SLAVES], apb_slave_24b_read_seq_h[TOTAL_SLAVES];

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "apb_virtual_24b_write_read_seq");
  extern task body();

endclass : apb_virtual_24b_write_read_seq

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_virtual_24b_write_read_seq
//--------------------------------------------------------------------------------------------
function apb_virtual_24b_write_read_seq::new(string name = "apb_virtual_24b_write_read_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task - body
//  Creates and starts the 24bit data of master and slave sequences
//--------------------------------------------------------------------------------------------
task apb_virtual_24b_write_read_seq::body();
  super.body();

	// Creates the objects for multiple master and slave
	foreach(apb_master_24b_write_seq_h[i]) begin
	  apb_master_24b_write_seq_h[i] = apb_master_sequence::type_id::create($sformatf("apb_master_24b_write_seq_h[%0d]", i));
	end

	foreach(apb_master_24b_read_seq_h[i]) begin
  	apb_master_24b_read_seq_h[i] = apb_master_sequence::type_id::create($sformatf("apb_master_24b_read_seq_h[%0d]", i));
	end

	foreach(apb_slave_24b_write_seq_h[i]) begin
  	apb_slave_24b_write_seq_h[i]=apb_slave_sequence::type_id::create($sformatf("apb_slave_24b_write_seq_h[%0d]", i));
	end

	foreach(apb_slave_24b_read_seq_h[i]) begin
  	apb_slave_24b_read_seq_h[i]=apb_slave_sequence::type_id::create($sformatf("apb_slave_24b_read_seq_h[%0d]", i));
	end

	// Write sequnce
  foreach(apb_master_24b_write_seq_h[i]) 
		if(!apb_master_24b_write_seq_h[i].randomize() with { 
						address inside {[master_addr.min_addr[i]:master_addr.max_addr[i]]};
						transfer_len == BIT_16;
		}) begin
      `uvm_error(get_type_name(), $sformatf("Randomization failed for master %0d", i))
    end

  fork
    begin
      foreach(apb_slave_24b_write_seq_h[i]) begin
        fork
          automatic int j = i;
			  	forever begin
            apb_slave_24b_write_seq_h[j].start(p_sequencer.apb_slave_seqr_h[j]);
          end
				join_none
      end
    end

    begin
      foreach(apb_master_24b_write_seq_h[i]) begin
        fork
          automatic int j =i;
          apb_master_24b_write_seq_h[j].start(p_sequencer.apb_master_seqr_h[j]);
        join_none
      end
    end
 	  wait fork;
  join 

	// Read Sequence
  foreach(apb_master_24b_read_seq_h[i]) 
		if(!apb_master_24b_read_seq_h[i].randomize() with { 
						address inside {[master_addr.min_addr[i]:master_addr.max_addr[i]]};
						read_write == READ;	
						transfer_len == BIT_16;
		}) begin
      `uvm_error(get_type_name(), $sformatf("Randomization failed for master %0d", i))
    end

  fork
    begin
      foreach(apb_slave_24b_read_seq_h[i]) begin
        fork
          automatic int j = i;
			  	forever begin
            apb_slave_24b_read_seq_h[j].start(p_sequencer.apb_slave_seqr_h[j]);
          end
				join_none
      end
    end

    begin
      foreach(apb_master_24b_read_seq_h[i]) begin
        fork
          automatic int j =i;
          apb_master_24b_read_seq_h[j].start(p_sequencer.apb_master_seqr_h[j]);
        join_none
      end
    end
 	  wait fork;
  join 

endtask : body

`endif

