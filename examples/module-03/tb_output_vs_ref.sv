module tb_output_vs_ref;

  int out_val, ref_val;

  task automatic count_out(output int v);
    for (int i = 1; i <= 3; i++) begin
      #10;
      v = i;
    end
  endtask

  task automatic count_ref(ref int v);
    for (int i = 1; i <= 3; i++) begin
      #10;
      v = i;
    end
  endtask

  initial fork
    count_out(out_val);
    count_ref(ref_val);
  join

  initial begin
    #15 $display("[%0t] out_val=%0d ref_val=%0d", $time, out_val, ref_val);
    #10 $display("[%0t] out_val=%0d ref_val=%0d", $time, out_val, ref_val);
    #10 $display("[%0t] out_val=%0d ref_val=%0d", $time, out_val, ref_val);
  end

endmodule
