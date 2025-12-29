`ifndef APB_VIRTUAL_32B_WRITE_MULTIPLE_MASTER_MULTIPLE_SLAVE_SEQ_INCLUDED_
`define APB_VIRTUAL_32B_WRITE_MULTIPLE_MASTER_MULTIPLE_SLAVE_SEQ_INCLUDED_

class apb_virtual_32b_write_multiple_master_multiple_slave_seq
  extends apb_virtual_base_seq;

  `uvm_object_utils(
    apb_virtual_32b_write_multiple_master_multiple_slave_seq
  )

  apb_master_32b_write_seq apb_master_32b_write_seq_master0[NO_OF_MASTERS];
  apb_master_32b_write_seq apb_master_32b_write_seq_master1[NO_OF_MASTERS];

  apb_slave_32b_write_seq  apb_slave_32b_write_seq_slave0[NO_OF_SLAVES];
  apb_slave_32b_write_seq  apb_slave_32b_write_seq_slave1[NO_OF_SLAVES];

  extern function new(
    string name="apb_virtual_32b_write_multiple_master_multiple_slave_seq"
  );
  extern task body();

endclass

function
apb_virtual_32b_write_multiple_master_multiple_slave_seq::new(
  string name="apb_virtual_32b_write_multiple_master_multiple_slave_seq"
);
  super.new(name);
endfunction

task
apb_virtual_32b_write_multiple_master_multiple_slave_seq::body();
  super.body();

  apb_master_32b_write_seq_master0 =
    apb_master_32b_write_seq::type_id::create(
      "apb_master_32b_write_seq_master0"
    );

  apb_master_32b_write_seq_master1 =
    apb_master_32b_write_seq::type_id::create(
      "apb_master_32b_write_seq_master1"
    );

  apb_slave_32b_write_seq_slave0 =
    apb_slave_32b_write_seq::type_id::create(
      "apb_slave_32b_write_seq_slave0"
    );

  apb_slave_32b_write_seq_slave1 =
    apb_slave_32b_write_seq::type_id::create(
      "apb_slave_32b_write_seq_slave1"
    );

  fork
    begin
      apb_slave_32b_write_seq_slave0.start(
        p_sequencer.apb_slave_seqr_h[0]
      );
    end
    begin
      apb_slave_32b_write_seq_slave1.start(
        p_sequencer.apb_slave_seqr_h[1]
      );
    end
    begin
      apb_master_32b_write_seq_master0.start(
        p_sequencer.apb_master_seqr_h[0]
      );
    end
    begin
      apb_master_32b_write_seq_master1.start(
        p_sequencer.apb_master_seqr_h[1]
      );
    end
  join

endtask

`endif

