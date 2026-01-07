`ifndef APB_VIRTUAL_8B_WRITE_SEQ_INCLUDED_
`define APB_VIRTUAL_8B_WRITE_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_virtual_8b_write_seq
// Creates and starts the master and slave vd_vws sequnences of variable data and variable 
// wait states.
//--------------------------------------------------------------------------------------------
class apb_virtual_8b_write_seq extends apb_virtual_base_seq;
  `uvm_object_utils(apb_virtual_8b_write_seq)

  //Variable: apb_master_8b_seq_h
  //Instatiation of apb_master_8b_write_seq
  apb_master_8b_write_seq apb_master_8b_write_seq_h[NO_OF_MASTERS];

  //Variable: apb_slave_8b_write_seq_h
  //Instantiation of apb_master_8b_write_seq
  apb_slave_8b_write_seq apb_slave_8b_write_seq_h[NO_OF_SLAVES];

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------

  extern function new(string name ="apb_virtual_8b_write_seq");
  extern task body();

endclass : apb_virtual_8b_write_seq
//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_virtual_8b_write_seq
//--------------------------------------------------------------------------------------------

function apb_virtual_8b_write_seq::new(string name ="apb_virtual_8b_write_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task - body
// Creates and starts the 8bit data of master and slave sequences
//--------------------------------------------------------------------------------------------
task apb_virtual_8b_write_seq::body();
  super.body();
	foreach(apb_master_8b_write_seq_h[i]) begin
  	apb_master_8b_write_seq_h[i]=apb_master_8b_write_seq::type_id::create($sformatf("apb_master_8b_write_seq_h[%0d]",i));
		//apb_master_8b_write_seq_h[i].randomize() with {choose_packet_data_seq == 0;};
	end

	foreach(apb_slave_8b_write_seq_h[i]) begin
  	apb_slave_8b_write_seq_h[i]=apb_slave_8b_write_seq::type_id::create($sformatf("apb_slave_8b_write_seq_h[%0d]",i));
		if(!apb_slave_8b_write_seq_h[i].randomize() with {choose_packet_data_seq == 0;})
       `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq")
	end
 /* 
  fork
  begin
	  foreach(apb_slave_8b_write_seq_h[i]) begin
			automatic j = i;
      forever begin
        if(!apb_slave_8b_write_seq_h[j].randomize() with {choose_packet_data_seq == 0; 
                                                                    }) begin
             `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq")
        end
        apb_slave_8b_write_seq_h[j].start(p_sequencer.apb_slave_seqr_h[i]);
		  end
		end
  end
  join_none
*/
/*
     fork begin 
        if(!apb_slave_8b_write_seq_h[0].randomize() with {choose_packet_data_seq == 0;
                                                                    }) begin
             `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq")
        end
        if(!apb_slave_8b_write_seq_h[1].randomize() with {choose_packet_data_seq == 0;
                                                                    }) begin
             `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq")
        end
        if(!apb_slave_8b_write_seq_h[2].randomize() with {choose_packet_data_seq == 0;
                                                                    }) begin
             `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq")
        end
        if(!apb_slave_8b_write_seq_h[3].randomize() with {choose_packet_data_seq == 0;
                                                                    }) begin
             `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq")
        end
        apb_slave_8b_write_seq_h[0].start(p_sequencer.apb_slave_seqr_h[0]);
        apb_slave_8b_write_seq_h[1].start(p_sequencer.apb_slave_seqr_h[1]);
        repeat(2) apb_slave_8b_write_seq_h[2].start(p_sequencer.apb_slave_seqr_h[2]);
        apb_slave_8b_write_seq_h[3].start(p_sequencer.apb_slave_seqr_h[3]);
			end
 join_none 
*/
  foreach(apb_slave_8b_write_seq_h[i]) begin
   fork  
     automatic int j = i;
     forever begin
       apb_slave_8b_write_seq_h[j].start(p_sequencer.apb_slave_seqr_h[j]);
      end
   join_none 
  end 

  fork
    begin: MASTER_WRITE_SEQ_0
      repeat(1) begin
          if(!apb_master_8b_write_seq_h[0].randomize() with {address_seq == 32'd100;
                                                                    }) begin
            `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq.sv")
          end
          if(!apb_master_8b_write_seq_h[1].randomize() with {address_seq == 32'd5000;
                                                                    }) begin
            `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq.sv")
          end
          if(!apb_master_8b_write_seq_h[2].randomize() with {address_seq == 32'd9000;
                                                                    }) begin
            `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq.sv")
          end
          if(!apb_master_8b_write_seq_h[3].randomize() with {address_seq == 32'd10000;
                                                                    }) begin
            `uvm_error(get_type_name(), "Randomization failed : Inside apb_virtual_8b_write_seq.sv")
          end
				  fork
        	  apb_master_8b_write_seq_h[0].start(p_sequencer.apb_master_seqr_h[0]);
        	  apb_master_8b_write_seq_h[1].start(p_sequencer.apb_master_seqr_h[1]);
        	  apb_master_8b_write_seq_h[2].start(p_sequencer.apb_master_seqr_h[2]);
        	  apb_master_8b_write_seq_h[3].start(p_sequencer.apb_master_seqr_h[3]);
          join_none
			end
    end
	
  join

 endtask : body

`endif
