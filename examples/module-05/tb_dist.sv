module tb_dist;

  class per_value;
    rand bit [1:0] x;
    constraint c { x dist {0 := 40, [1:3] := 60}; }
  endclass

  class per_range;
    rand bit [1:0] x;
    constraint c { x dist {0 :/ 40, [1:3] :/ 60}; }
  endclass

  per_value pv;
  per_range pr;
  int       hist_v[4], hist_r[4];

  initial begin
    pv = new();
    pr = new();
    repeat (2200) begin
      if (!pv.randomize()) $fatal(1, "randomize failed");
      hist_v[pv.x]++;
    end
    repeat (1000) begin
      if (!pr.randomize()) $fatal(1, "randomize failed");
      hist_r[pr.x]++;
    end
    $display(":=  over 2200 calls : %p", hist_v);
    $display(":/  over 1000 calls : %p", hist_r);
  end

endmodule
