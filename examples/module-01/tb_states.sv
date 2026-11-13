module tb_states;

  logic [3:0] l4;   // four-state
  bit   [3:0] b2;   // two-state

  initial begin
    $display("default : l4=%b  b2=%b", l4, b2);

    l4 = 4'b1x0z;
    b2 = l4;        // X and Z are silently converted to 0
    $display("assigned: l4=%b  b2=%b", l4, b2);

    if ($isunknown(l4)) $display("l4 contains X or Z");
    if (!$isunknown(b2)) $display("b2 can never contain X or Z");

    l4 = 4'b1010;
    l4 = l4 + 4'b000x;   // one unknown bit poisons the whole sum
    $display("sum     : l4=%b", l4);
  end

endmodule
