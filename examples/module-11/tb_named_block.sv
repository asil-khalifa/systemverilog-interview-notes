module tb_named_block;

  int data [8] = '{3, 7, 0, 9, 4, 0, 1, 5};

  initial begin

    // ---- 1. leave a named sequential block early ----
    begin : search
      foreach (data[i]) begin
        if (data[i] == 0) begin
          $display("1. first zero found at index %0d", i);
          disable search;
        end
      end
      $display("   (not printed: the block was disabled before reaching this line)");
    end : search
    $display("2. execution continues after the named block");

    // ---- 2. name the loop BODY: disable acts like 'continue' ----
    for (int i = 0; i < 4; i++) begin : body
      if (i == 1) disable body;
      $display("3. i = %0d", i);
    end

    // ---- 3. a named fork block: stop the slower thread ----
    fork : race
      begin : thread_a
        #30 $display("[%0t] thread_a done", $time);
      end
      begin : thread_b
        #10 $display("[%0t] thread_b done", $time);
      end
    join_any
    disable race;
    $display("[%0t] 4. fork block 'race' disabled", $time);

    #50 $display("[%0t] 5. end of test", $time);
  end

endmodule
