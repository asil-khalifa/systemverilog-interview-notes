module tb_cg_per_instance;

  covergroup cg_port with function sample(bit [1:0] v);
    option.per_instance = 1;
    cp_v: coverpoint v;
  endgroup

  cg_port cg_port_a = new();
  cg_port cg_port_b = new();

  initial begin
    cg_port_a.set_inst_name("port_a");
    cg_port_b.set_inst_name("port_b");

    cg_port_a.sample(2'd0);
    cg_port_a.sample(2'd1);
    cg_port_b.sample(2'd1);
    cg_port_b.sample(2'd2);

    $display("port_a instance coverage = %0.2f%%", cg_port_a.get_inst_coverage());
    $display("port_b instance coverage = %0.2f%%", cg_port_b.get_inst_coverage());
  end

endmodule
