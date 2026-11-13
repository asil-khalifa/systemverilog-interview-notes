module ex04_alu_operations;

  virtual class alu_operation;
    pure virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
    pure virtual function string op_name();
  endclass

  class add_op extends alu_operation;
    virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
      return {1'b0, a} + {1'b0, b};
    endfunction
    virtual function string op_name();
      return "ADD";
    endfunction
  endclass

  class sub_op extends alu_operation;
    virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
      return {1'b0, a} - {1'b0, b};
    endfunction
    virtual function string op_name();
      return "SUB";
    endfunction
  endclass

  class xor_op extends alu_operation;
    virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
      return {1'b0, a ^ b};
    endfunction
    virtual function string op_name();
      return "XOR";
    endfunction
  endclass

  alu_operation ops [3];
  add_op        op_a;
  sub_op        op_s;
  xor_op        op_x;

  initial begin
    op_a = new();  op_s = new();  op_x = new();
    ops[0] = op_a;
    ops[1] = op_s;
    ops[2] = op_x;

    foreach (ops[i])
      $display("%s(200, 100) = %0d", ops[i].op_name(), ops[i].calc(8'd200, 8'd100));
    $display("%s(5, 10) = %0d", ops[1].op_name(), ops[1].calc(8'd5, 8'd10));
  end

endmodule
