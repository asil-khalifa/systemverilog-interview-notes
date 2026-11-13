module counter2 (
  input  logic       clk, rst_n, en,
  output logic [1:0] count
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)  count <= '0;
    else if (en) count <= count + 2'd1;
endmodule

module fx09_counter_sva_cov;

  logic       clk = 0;
  logic       rst_n, en;
  logic [1:0] count;
  int         fail_cnt;

  counter2 dut (.*);

  always #5 clk = ~clk;

  // ---------------- assertions ----------------
  a_inc: assert property (@(posedge clk) disable iff (!rst_n)
                          en |=> count == $past(count) + 2'd1)
         else begin fail_cnt++; $error("counter did not increment"); end

  a_hold: assert property (@(posedge clk) disable iff (!rst_n)
                           !en |=> count == $past(count))
          else begin fail_cnt++; $error("counter changed while disabled"); end

  // ---------------- coverage ----------------
  covergroup count_cg @(posedge clk iff rst_n);
    cp_value: coverpoint count;                       // four automatic bins
    cp_wrap : coverpoint count { bins wrap = (2'd3 => 2'd0); }
  endgroup

  count_cg cg = new();

  // ---------------- stimulus ----------------
  initial begin
    rst_n = 0;
    en    = 0;
    repeat (2) @(negedge clk);
    rst_n = 1;
    en    = 1;
    repeat (6) @(negedge clk);        // six rising edges with en = 1
    en = 0;
    repeat (2) @(negedge clk);        // two rising edges with en = 0
    $display("count=%0d", count);
    $display("assertion failures=%0d", fail_cnt);
    $display("coverage=%0.2f%%", cg.get_coverage());
    $finish;
  end

endmodule
