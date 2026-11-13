module fx04_polymorphism;

  virtual class alu_operation;
    string name;

    function new(string name);
      this.name = name;
    endfunction

    pure virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);

    function void show(logic [7:0] a, logic [7:0] b);
      $display("%-4s %0d, %0d -> %0d", name, a, b, calc(a, b));
    endfunction
  endclass

  class op_add extends alu_operation;
    function new();
      super.new("add");
    endfunction
    virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);
      logic [8:0] r;
      r = a + b;
      return r;
    endfunction
  endclass

  class op_sub extends alu_operation;
    function new();
      super.new("sub");
    endfunction
    virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);
      logic [8:0] r;
      r = a - b;
      return r;
    endfunction
  endclass

  class op_xor extends alu_operation;
    function new();
      super.new("xor");
    endfunction
    virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);
      return {1'b0, a ^ b};
    endfunction
  endclass

  alu_operation ops [$];
  op_add        h_add;
  op_sub        h_sub;
  op_xor        h_xor;

  initial begin
    h_add = new();
    h_sub = new();
    h_xor = new();
    ops.push_back(h_add);          // derived handles stored as base handles
    ops.push_back(h_sub);
    ops.push_back(h_xor);

    foreach (ops[i]) ops[i].show(200, 100);
    ops[1].show(100, 200);
  end

endmodule
