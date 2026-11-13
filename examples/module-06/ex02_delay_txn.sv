module ex02_delay_txn;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  class alu_delay_txn extends alu_txn;
    rand int unsigned delay;

    constraint delay_c { delay inside {[0:5]}; }

    virtual function string convert2string();
      return {super.convert2string(), $sformatf(" delay=%0d", delay)};
    endfunction

    virtual function alu_txn copy();
      alu_delay_txn c = new();
      c.a      = a;
      c.b      = b;
      c.op     = op;
      c.result = result;
      c.id     = id;
      c.delay  = delay;
      return c;
    endfunction
  endclass

  alu_delay_txn d, d2;
  alu_txn       base_h, base_copy;

  initial begin
    d       = new();
    d.id    = 7;
    d.op    = ALU_OR;
    d.a     = 8'h0F;
    d.b     = 8'hF0;
    d.delay = 3;

    base_h    = d;                    // base-class handle to the derived object
    base_copy = base_h.copy();        // virtual: the derived copy() runs
    base_copy.print("COPY");          // virtual: the derived convert2string() runs

    if ($cast(d2, base_copy))
      $display("the copy is an alu_delay_txn, delay=%0d", d2.delay);

    base_copy = new();                // a plain alu_txn
    if (!$cast(d2, base_copy))
      $display("a plain alu_txn cannot be cast to alu_delay_txn");
  end

endmodule
