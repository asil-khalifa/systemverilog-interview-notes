module ex04_scoreboard;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  alu_txn      exp_q[$];
  int unsigned n_pass, n_fail;

  function automatic void write_expected(alu_txn t);
    alu_txn e = t.copy();
    e.result = alu_predict(e);
    exp_q.push_back(e);
  endfunction

  function automatic void write_actual(alu_txn act);
    alu_txn e;
    if (exp_q.size() == 0) begin
      n_fail++;
      $display("FAIL unexpected {%s}", act.convert2string());
      return;
    end
    e = exp_q.pop_front();
    if (e.compare(act)) begin
      n_pass++;
      $display("PASS {%s}", act.convert2string());
    end
    else begin
      n_fail++;
      $display("FAIL expected {%s}", e.convert2string());
      $display("     actual   {%s}", act.convert2string());
    end
  endfunction

  function automatic void report();
    if (exp_q.size() != 0) begin
      n_fail++;
      $display("FAIL %0d expected transaction(s) never observed", exp_q.size());
    end
    $display("scoreboard: %0d passed, %0d failed", n_pass, n_fail);
    if (n_fail == 0 && n_pass > 0) $display("TEST PASSED");
    else                           $display("TEST FAILED");
  endfunction

  function automatic alu_txn make(int unsigned id, alu_op_e op, bit [7:0] a, bit [7:0] b);
    alu_txn t = new();
    t.id = id;
    t.op = op;
    t.a  = a;
    t.b  = b;
    return t;
  endfunction

  alu_txn s, d;

  initial begin
    s = make(0, ALU_ADD, 8'd200, 8'd100);  write_expected(s);
    d = s.copy();  d.result = 9'h12C;      write_actual(d);     // correct

    s = make(1, ALU_SUB, 8'd5, 8'd10);     write_expected(s);
    d = s.copy();  d.result = 9'h0FB;      write_actual(d);     // borrow bit lost

    s = make(2, ALU_SHL, 8'h81, 8'h00);    write_expected(s);
    d = s.copy();  d.result = 'x;          write_actual(d);     // output is X

    d = make(3, ALU_OR, 8'h01, 8'h02);
    d.result = 9'h003;                     write_actual(d);     // nothing was expected

    s = make(4, ALU_AND, 8'hFF, 8'h0F);    write_expected(s);   // never observed

    report();
  end

endmodule
