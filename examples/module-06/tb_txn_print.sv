module tb_txn_print;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function string convert2string();
      return $sformatf("id=%0d op=%s a=0x%h b=0x%h result=0x%h",
                       id, op.name(), a, b, result);
    endfunction

    virtual function void print(string tag = "");
      $display("[%0t] %s: %s", $time, tag, convert2string());
    endfunction
  endclass

  alu_txn t;

  initial begin
    t    = new();
    t.id = 1;
    t.op = ALU_ADD;
    t.a  = 8'd200;
    t.b  = 8'd100;
    t.print("GEN");

    #10;
    t.result = 9'd300;
    t.print("MON");

    $display("SCB: unexpected result in {%s}", t.convert2string());
  end

endmodule
