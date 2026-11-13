module tb_blocks;

  int data [5] = '{3, 8, 12, 7, 20};

  initial begin : main_blk
    int found_at;
    found_at = -1;

    for (int i = 0; i < 5; i++) begin : scan
      if (data[i] > 10) begin
        found_at = i;
        break;
      end
    end : scan
    $display("1. first value above 10 is at index %0d", found_at);

    begin : guarded
      $display("2. inside guarded block");
      if (found_at == 2) disable guarded;
      $display("   this line is skipped");
    end : guarded
    $display("3. after guarded block");
  end : main_blk

endmodule
