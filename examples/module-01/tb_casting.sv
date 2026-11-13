module tb_casting;

  typedef enum bit [1:0] {OP_ADD, OP_SUB, OP_MUL, OP_DIV} op_e;
  typedef enum {RD = 1, WR = 2}                           dir_e;
  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } nibbles_t;

  int         i;
  real        r;
  byte        b;
  logic [3:0] n;
  nibbles_t   nb;
  op_e        op;
  dir_e       dir;

  initial begin
    // ---- implicit conversions ----
    r = 3.7;
    i = r;                    $display("1.  i = 3.7              -> %0d", i);
    n = 8'hAB;                $display("2.  4-bit n = 8'hAB      -> %h", n);
    i = n;                    $display("3.  int = n              -> %0d", i);

    // ---- static casts ----
    i  = int'(2.4);           $display("4.  int'(2.4)            -> %0d", i);
    b  = byte'(300);          $display("5.  byte'(300)           -> %0d", b);
    n  = 4'(8'hAB);           $display("6.  4'(8'hAB)            -> %h", n);
    i  = signed'(4'b1111);    $display("7.  signed'(4'b1111)     -> %0d", i);
    nb = nibbles_t'(8'h5C);   $display("8.  nibbles_t'(8'h5C)    -> hi=%h lo=%h", nb.hi, nb.lo);
    op = op_e'(2);            $display("9.  op_e'(2)             -> %s", op.name());
    r  = real'(7) / 2;        $display("10. real'(7) / 2         -> %0.1f", r);

    // ---- dynamic casts ----
    if ($cast(dir, 2))        $display("11. $cast(dir, 2) ok     -> %s", dir.name());
    if (!$cast(dir, 5))       $display("12. $cast(dir, 5) failed -> dir stays %s", dir.name());

    dir = dir_e'(5);          $display("13. dir_e'(5)            -> value %0d, name '%s'",
                                       dir, dir.name());
    // $cast(dir, 7);         // task form: this line would produce a run-time error
  end

endmodule
