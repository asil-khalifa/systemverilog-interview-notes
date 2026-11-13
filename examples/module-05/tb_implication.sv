module tb_implication;

  class cfg;
    rand bit       mode;
    rand bit [1:0] len;
    constraint imp_c { (mode == 1) -> (len == 3); }
  endclass

  cfg c;
  int mode_one;

  initial begin
    c = new();

    // Forward direction: force the condition
    if (!c.randomize() with { mode == 1; }) $fatal(1, "randomize failed");
    $display("forced mode=1 : mode=%0d len=%0d", c.mode, c.len);

    // Backward direction: force the consequence to be false
    if (!c.randomize() with { len == 2; }) $fatal(1, "randomize failed");
    $display("forced len=2  : mode=%0d len=%0d", c.mode, c.len);

    // Distribution
    repeat (1000) begin
      if (!c.randomize()) $fatal(1, "randomize failed");
      if (c.mode == 1) mode_one++;
    end
    $display("mode was 1 in %0d of 1000 calls", mode_one);
  end

endmodule
