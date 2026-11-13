module tb_hello;

  int unsigned count;
  string       name = "SystemVerilog";

  initial begin
    count = 3;
    repeat (count) begin
      $display("[%0t] Hello from %s", $time, name);
      #10;
    end
    $display("[%0t] Done", $time);
    $finish;
  end

endmodule
