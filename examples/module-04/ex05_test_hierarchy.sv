module ex05_test_hierarchy;

  class base_test;
    string name = "base_test";

    virtual function int num_txns();
      return 2;
    endfunction

    virtual function string stimulus(int i);
      return $sformatf("normal txn %0d", i);
    endfunction

    virtual task run();
      $display("--- %s ---", name);
      for (int i = 0; i < num_txns(); i++) begin
        #10;
        $display("[%0t] %s", $time, stimulus(i));
      end
    endtask
  endclass

  class error_test extends base_test;
    function new();
      name = "error_test";               // change the inherited property's value
    endfunction

    virtual function int num_txns();
      return 3;
    endfunction

    virtual function string stimulus(int i);
      if (i == 1) return "ERROR injection";
      return super.stimulus(i);
    endfunction
  endclass

  base_test  t;
  base_test  b;
  error_test e;

  initial begin
    b = new();
    e = new();
    t = b;  t.run();
    t = e;  t.run();
  end

endmodule
