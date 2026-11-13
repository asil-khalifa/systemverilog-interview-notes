module tb_class_methods;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    // Void function: prints the object. Zero time.
    function void print(string tag = "");
      $display("%s id=%0d op=%s a=%0d b=%0d result=%0d",
               tag, id, op.name(), a, b, result);
    endfunction

    // Function returning a handle to a new object with the same contents
    function alu_txn copy();
      alu_txn t;
      t        = new();
      t.a      = a;
      t.b      = b;
      t.op     = op;
      t.result = result;
      t.id     = id;
      return t;
    endfunction

    // Function returning a status bit; the argument is a handle to another object
    function bit compare(alu_txn rhs);
      return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
    endfunction

    // Body written outside the class
    extern function logic [8:0] expected();
  endclass

  function logic [8:0] alu_txn::expected();
    case (op)
      ALU_ADD: return {1'b0, a} + {1'b0, b};
      ALU_SUB: return {1'b0, a} - {1'b0, b};
      default: return 'x;        // remaining operations omitted in this preview
    endcase
  endfunction

  class ticker;
    string name;

    function new(string name = "ticker");     // constructor: a function, zero time
      this.name = name;                       // this.name is the property, name the argument
    endfunction

    task run(int n, int period);              // a task: consumes time
      repeat (n) begin
        #period;
        $display("[%0t] %s tick", $time, name);
      end
    endtask
  endclass

  alu_txn t1, t2;
  ticker  tk;

  initial begin
    t1 = new();
    t1.id     = 1;
    t1.a      = 8'd200;
    t1.b      = 8'd100;
    t1.op     = ALU_ADD;
    t1.result = t1.expected();
    t1.print("[GEN]");

    t2    = t1.copy();
    t2.id = 2;
    t2.print("[CPY]");
    $display("compare before change: %b", t1.compare(t2));

    t2.b = 8'd50;
    $display("compare after  change: %b", t1.compare(t2));

    tk = new("clk_a");
    tk.run(2, 10);
  end

endmodule
