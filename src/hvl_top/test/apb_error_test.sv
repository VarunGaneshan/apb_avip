`ifndef APB_ERROR_TEST_INCLUDED_
`define APB_ERROR_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: apb_error_test
//  Extends the base test and starts the virtual sequence of 8 bit
//--------------------------------------------------------------------------------------------
class apb_error_test extends apb_base_test;
  `uvm_component_utils(apb_error_test)
 
  //Variable: apb_virtual_error_seq_h'
  //Instatiation of apb_virtual_error_seq
  apb_virtual_error_seq apb_virtual_error_seq_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "apb_error_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : apb_error_test

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_error_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function apb_error_test::new(string name = "apb_error_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: run_phase
//  Creates the apb_virtual_8b_write_read_seq sequnce and starts the 8b virtual sequences
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task apb_error_test::run_phase(uvm_phase phase);
  int num, k, q[$];

  apb_virtual_error_seq_h = apb_virtual_error_seq::type_id::create("apb_virtual_error_seq_h");
  

	num = $urandom_range(1, NO_OF_MASTERS);  

	if (NO_OF_SLAVES > 0) begin
  	num = $urandom_range(1, NO_OF_SLAVES);  
	end else begin
	  num = 1;  
	end

	repeat(num) begin
	  k = $urandom_range(0,NO_OF_MASTERS);
		q.push_back(k);
	end							
	
	foreach(q[i]) begin
		master_addr.min_addr[i] = master_addr.max_addr[i] + 1;
		master_addr.max_addr[i] = master_addr.max_addr[i] + SLAVE_MEMORY_GAP;
	end
	foreach(master_addr.min_addr[i]) begin
					$display("ERROR test : master[%0d] to send to slave addr min : %0d | max : %0d",i,master_addr.min_addr[i],master_addr.max_addr[i]);
	end

  phase.raise_objection(this);
    apb_virtual_error_seq_h.start(apb_env_h.apb_virtual_seqr_h);
   //#100;

  phase.drop_objection(this);

endtask : run_phase

`endif
