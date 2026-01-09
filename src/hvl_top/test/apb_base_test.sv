`ifndef APB_BASE_TEST_INCLUDED_
`define APB_BASE_TEST_INCLUDED_
// update before compiling
//--------------------------------------------------------------------------------------------
// Class: apb_base_test
//  Base test has the testcase scenarios for the tesbench
//  Env and Config are created in apb_base_test
//  Sequences are created and started in the test
//--------------------------------------------------------------------------------------------
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)
  
  //Variable: env_h
  //Declaring a handle for env
  apb_env apb_env_h;

	//Variable : master_to_slave_map
	// USed to map which master will send data to which slave
	int master_to_slave_map[];

  //Variable: apb_env_cfg_h
  //Declaring a handle for env_cfg_h
  apb_env_config apb_env_cfg_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "apb_base_test", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void setup_apb_env_config();
  extern virtual function void setup_apb_master_agent_config();
  extern virtual function void setup_apb_slave_agent_config();
  extern virtual function void end_of_elaboration_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function void map_master_to_slave();
endclass : apb_base_test

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_base_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function apb_base_test::new(string name = "apb_base_test",uvm_component parent = null);
  super.new(name, parent);
	master_to_slave_map = new[NO_OF_MASTERS];
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//  Creates env and required configuarions
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void apb_base_test::build_phase(uvm_phase phase);
	apb_report_server rs;
  super.build_phase(phase);

	// report server instantiation
	//rs = apb_report_server::type_id::create("apb_report_server");
  rs = new();
	uvm_report_server::set_server(rs);

  setup_apb_env_config();
  apb_env_h = apb_env::type_id::create("apb_env",this);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function : setup_apb_env_config
//  It calls the master agent config setup and slave agent config steup functions
//--------------------------------------------------------------------------------------------
function void apb_base_test::setup_apb_env_config();
  apb_env_cfg_h = apb_env_config::type_id::create("apb_env_cfg_h");
  apb_env_cfg_h.no_of_slaves      = NO_OF_SLAVES;
  apb_env_cfg_h.no_of_masters     = NO_OF_MASTERS;
  apb_env_cfg_h.has_scoreboard    = HAS_SCOREBOARD;
  apb_env_cfg_h.has_virtual_seqr  = HAS_VIRTUAL_SEQR;

  // Creating multiple master agents
	apb_env_cfg_h.apb_master_agent_cfg_h = new[apb_env_cfg_h.no_of_masters];
	foreach(apb_env_cfg_h.apb_master_agent_cfg_h[i]) begin
		apb_env_cfg_h.apb_master_agent_cfg_h[i] = apb_master_agent_config::type_id::create($sformatf("apb_master_agent_cfg_h%0d",i));
    apb_env_cfg_h.apb_master_agent_cfg_h[i].master_id = i;
	end

  //Setting up the configuration for master agent
  setup_apb_master_agent_config();

  //Setting the master agent configuration into config_db
	foreach(apb_env_cfg_h.apb_master_agent_cfg_h[i]) begin
		uvm_config_db#(apb_master_agent_config)::set(this,"*",$sformatf("apb_master_agent_config_%0d",i),apb_env_cfg_h.apb_master_agent_cfg_h[i]);
	end

  setup_apb_slave_agent_config();

  uvm_config_db#(apb_env_config)::set(this,"*","apb_env_config",apb_env_cfg_h);
  `uvm_info(get_type_name(),$sformatf("\nAPB_ENV_CONFIG\n%s",apb_env_cfg_h.sprint()),UVM_LOW);

endfunction : setup_apb_env_config

//--------------------------------------------------------------------------------------------
// Function : setup_apb_master_agent_config
//  Sets the configurations to the corresponding variables in apb master agent config
//  Creates the master agent config
//  Sets apb master agent config into configdb 
//--------------------------------------------------------------------------------------------
function void apb_base_test::setup_apb_master_agent_config();
  bit [63:0]local_min_address;
  bit [63:0]local_max_address;
 
	foreach(apb_env_cfg_h.apb_master_agent_cfg_h[i]) begin	
  	if(MASTER_AGENT_ACTIVE === 1) begin
    	apb_env_cfg_h.apb_master_agent_cfg_h[i].is_active = uvm_active_passive_enum'(UVM_ACTIVE);
  	end
  	else begin
    	apb_env_cfg_h.apb_master_agent_cfg_h[i].is_active = uvm_active_passive_enum'(UVM_PASSIVE);
  	end
	end

  apb_env_cfg_h.apb_master_agent_cfg_h[0].no_of_slaves = NO_OF_SLAVES;
  apb_env_cfg_h.apb_master_agent_cfg_h[0].has_coverage = 1;
  apb_env_cfg_h.apb_master_agent_cfg_h[0].master_id    = 0;

 	for(int i = 0; i < NO_OF_SLAVES; i++) begin
  	if(i == 0) begin
    	apb_env_cfg_h.apb_master_agent_cfg_h[0].master_min_addr_range(i,0);
    	local_min_address = apb_master_agent_config::master_min_addr_range_array[i];
      slave_addr.min_addr[i] = apb_master_agent_config::master_min_addr_range_array[i];

    	apb_env_cfg_h.apb_master_agent_cfg_h[0].master_max_addr_range(i,2**(SLAVE_MEMORY_SIZE)-1 );
    	local_max_address = apb_master_agent_config::master_max_addr_range_array[i];
			slave_addr.max_addr[i] = apb_master_agent_config::master_max_addr_range_array[i];
  	end
  	else begin
    	apb_env_cfg_h.apb_master_agent_cfg_h[0].master_min_addr_range(i,local_max_address + SLAVE_MEMORY_GAP);
    	local_min_address = apb_master_agent_config::master_min_addr_range_array[i];
      slave_addr.min_addr[i] = apb_master_agent_config::master_min_addr_range_array[i];

    	apb_env_cfg_h.apb_master_agent_cfg_h[0].master_max_addr_range(i,local_max_address+2**(SLAVE_MEMORY_SIZE)-1 + SLAVE_MEMORY_GAP);
    	local_max_address = apb_master_agent_config::master_max_addr_range_array[i];
      slave_addr.max_addr[i] = apb_master_agent_config::master_max_addr_range_array[i];
  	end
	end

  foreach(slave_addr.min_addr[i]) $display("array min = %0d | max = %0d",slave_addr.min_addr[i],slave_addr.max_addr[i]);
	
	for(int i = 0; i < NO_OF_SLAVES; i++) begin
    `uvm_info(get_type_name(),$sformatf("SLAVE[%0d] : min addr = %0d | max_addr = %0d",i,apb_master_agent_config::master_min_addr_range_array[i],apb_master_agent_config::master_max_addr_range_array[i]), UVM_MEDIUM)
	end

  map_master_to_slave();
  foreach(master_addr.min_addr[i])
		$display("After mapping :master[%0d] to send to slave : min = %0d | max = %0d",i,master_addr.min_addr[i],master_addr.max_addr[i]);

endfunction : setup_apb_master_agent_config

//--------------------------------------------------------------------------------------------
// Function : setup_apb_slave_agent_config
//  It calls the master agent config setup and slave agent config steup functions
//--------------------------------------------------------------------------------------------
function void apb_base_test::setup_apb_slave_agent_config();
  apb_env_cfg_h.apb_slave_agent_cfg_h = new[apb_env_cfg_h.no_of_slaves];
  foreach(apb_env_cfg_h.apb_slave_agent_cfg_h[i]) begin
    apb_env_cfg_h.apb_slave_agent_cfg_h[i] = apb_slave_agent_config::type_id::create($sformatf("apb_slave_agent_cfg_h[%0d]",i));
    apb_env_cfg_h.apb_slave_agent_cfg_h[i].slave_id       = i;
    apb_env_cfg_h.apb_slave_agent_cfg_h[i].slave_selected = 0;
		apb_env_cfg_h.apb_slave_agent_cfg_h[i].min_address    = apb_master_agent_config::master_min_addr_range_array[i];
		apb_env_cfg_h.apb_slave_agent_cfg_h[i].max_address    = apb_master_agent_config::master_max_addr_range_array[i];
    if(SLAVE_AGENT_ACTIVE === 1) begin
      apb_env_cfg_h.apb_slave_agent_cfg_h[i].is_active = uvm_active_passive_enum'(UVM_ACTIVE);
    end
    else begin
      apb_env_cfg_h.apb_slave_agent_cfg_h[i].is_active = uvm_active_passive_enum'(UVM_PASSIVE);
    end
    apb_env_cfg_h.apb_slave_agent_cfg_h[i].has_coverage = 1; 
    uvm_config_db #(apb_slave_agent_config)::set(this,$sformatf("*env*"),$sformatf("apb_slave_agent_config_%0d",i),apb_env_cfg_h.apb_slave_agent_cfg_h[i]);
   `uvm_info(get_type_name(),$sformatf("\nAPB_SLAVE_CONFIG[%0d]\n%s",i,apb_env_cfg_h.apb_slave_agent_cfg_h[i].sprint()),UVM_LOW);
  end

endfunction : setup_apb_slave_agent_config

//--------------------------------------------------------------------------------------------
// Function : master_to_slave_map
//  It calls the min and max addr previosly defined to be assigned to master map
//--------------------------------------------------------------------------------------------
function void apb_base_test::map_master_to_slave();
  int i, m, slave_idx, target_slave, num, max, masters_to_assign;
  bit master_assigned[NO_OF_MASTERS];
  
  for(i = 0; i < NO_OF_MASTERS; i++) begin
    master_assigned[i] = 0;
  end
  
  if(!MULTIPLE_MASTER_TO_SAME_SLAVE) begin
    for(i = 0; i < NO_OF_MASTERS; i++) begin
      slave_idx = i % NO_OF_SLAVES;
      master_addr.min_addr[i] = slave_addr.min_addr[slave_idx];
      master_addr.max_addr[i] = slave_addr.max_addr[slave_idx];
    end
    return;
  end
  
  max = (NO_OF_MASTERS < NO_OF_SLAVES + 1) ? NO_OF_MASTERS : NO_OF_SLAVES + 1;
  num = $urandom_range(2, max);
  target_slave = $urandom_range(0, NO_OF_SLAVES - 1);
  masters_to_assign = NO_OF_MASTERS;
  
  for(i = 0; i < num && masters_to_assign > 0; i++) begin
    do begin
      m = $urandom_range(0, NO_OF_MASTERS - 1);
    end while(master_assigned[m]);
    
    master_addr.min_addr[m] = slave_addr.min_addr[target_slave];
    master_addr.max_addr[m] = slave_addr.max_addr[target_slave];
    master_assigned[m] = 1;
    masters_to_assign--;
  end
  
  for(m = 0; m < NO_OF_MASTERS; m++) begin
    if(!master_assigned[m]) begin
      if(NO_OF_SLAVES > 1) begin
        do begin
          slave_idx = $urandom_range(0, NO_OF_SLAVES - 1);
        end while(slave_idx == target_slave);
      end else begin
        slave_idx = 0; 
      end
      
      master_addr.min_addr[m] = slave_addr.min_addr[slave_idx];
      master_addr.max_addr[m] = slave_addr.max_addr[slave_idx];
    end
  end
	
endfunction

//--------------------------------------------------------------------------------------------
// Function: end_of_elaboration_phase
//  Used to print topology
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void apb_base_test::end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  uvm_top.print_topology();
  uvm_test_done.set_drain_time(this,1000ns);
endfunction  : end_of_elaboration_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
//  Used to give 100ns delay to complete the run_phase.
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task apb_base_test::run_phase(uvm_phase phase);

  phase.raise_objection(this);
  super.run_phase(phase);
  #10;
  phase.drop_objection(this);

endtask : run_phase

`endif

