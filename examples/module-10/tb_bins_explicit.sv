module tb_bins_explicit;

  bit [7:0] a;

  covergroup cg_a;
    cp_a: coverpoint a {
      bins zero   = {0};
      bins low    = {[1:15]};
      bins mid[4] = {[16:239]};
      bins high   = {[240:254]};
      bins max    = {255};
    }
    cp_pow2: coverpoint a {
      bins pow2[] = {1, 2, 4, 8, 16, 32, 64, 128};
      bins others = default;
    }
  endgroup

  cg_a cg = new();

  initial begin
    a = 0;    cg.sample();
    a = 5;    cg.sample();
    a = 9;    cg.sample();
    a = 100;  cg.sample();
    a = 255;  cg.sample();
    a = 200;  cg.sample();
    a = 64;   cg.sample();

    $display("cp_a    = %0.2f%%", cg.cp_a.get_coverage());
    $display("cp_pow2 = %0.2f%%", cg.cp_pow2.get_coverage());
    $display("cg_a    = %0.2f%%", cg.get_coverage());
  end

endmodule
