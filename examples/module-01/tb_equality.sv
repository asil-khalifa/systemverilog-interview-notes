module tb_equality;

  logic [3:0] a, b, c;
  logic [7:0] actual, expected;

  initial begin
    a = 4'b10x1;
    b = 4'b10x1;
    c = 4'b00x1;

    $display("1. a == b : %b    a === b : %b", a == b, a === b);
    $display("2. a != b : %b    a !== b : %b", a != b, a !== b);
    $display("3. a == c : %b    a === c : %b", a == c, a === c);

    if (a == b) $display("4. if (a == b) : taken");
    else        $display("4. if (a == b) : NOT taken, X is treated as false");

    if (a != b) $display("5. if (a != b) : taken");
    else        $display("5. if (a != b) : NOT taken either");

    // The scoreboard trap: the DUT output is X
    expected = 8'h3C;
    actual   = 8'hxx;

    if (actual != expected)  $display("6. using != : MISMATCH reported");
    else                     $display("6. using != : no mismatch reported  <-- bug hidden");

    if (actual !== expected) $display("7. using !== : MISMATCH reported    <-- correct");
    else                     $display("7. using !== : no mismatch reported");
  end

endmodule
