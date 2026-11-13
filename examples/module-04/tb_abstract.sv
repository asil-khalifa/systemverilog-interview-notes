module tb_abstract;

  virtual class component;
    string name;

    function new(string name);
      this.name = name;
    endfunction

    pure virtual task run();
    pure virtual function string kind();

    function void report();                       // shared code, written once
      $display("%s is a %s", name, kind());
    endfunction
  endclass

  class demo_driver extends component;
    function new(string name);
      super.new(name);
    endfunction

    virtual task run();
      #10 $display("[%0t] %s: driving", $time, name);
    endtask

    virtual function string kind();
      return "driver";
    endfunction
  endclass

  class demo_monitor extends component;
    function new(string name);
      super.new(name);
    endfunction

    virtual task run();
      #5 $display("[%0t] %s: monitoring", $time, name);
    endtask

    virtual function string kind();
      return "monitor";
    endfunction
  endclass

  component    comps [2];        // handles of the abstract type are allowed
  demo_driver  d;
  demo_monitor m;

  initial begin
    d = new("drv0");
    m = new("mon0");
    comps[0] = d;
    comps[1] = m;

    foreach (comps[i]) comps[i].report();
    foreach (comps[i]) comps[i].run();          // one after the other

    // comps[0] = new("x");                     // ILLEGAL: component is abstract
  end

endmodule
