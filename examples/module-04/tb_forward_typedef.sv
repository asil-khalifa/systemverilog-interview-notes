module tb_forward_typedef;

  typedef class demo_driver;          // forward declaration

  class demo_monitor;
    string      name = "monitor";
    demo_driver drv;                  // legal because of the typedef above
  endclass

  class demo_driver;
    string       name = "driver";
    demo_monitor mon;
  endclass

  demo_monitor m;
  demo_driver  d;

  initial begin
    m = new();
    d = new();
    m.drv = d;                        // connect the two objects to each other
    d.mon = m;
    $display("%s knows %s", m.name, m.drv.name);
    $display("%s knows %s", d.name, d.mon.name);
  end

endmodule
