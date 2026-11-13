module tb_overload_workaround;

  class logger;
    string prefix;

    // One constructor serves "no argument" and "with argument"
    function new(string prefix = "LOG");
      this.prefix = prefix;
    endfunction

    // One method serves three calling styles
    function void log(string msg, int value = -1, string unit = "");
      if (value == -1) $display("%s: %s", prefix, msg);
      else             $display("%s: %s = %0d%s", prefix, msg, value, unit);
    endfunction

    // A static function used as a second, named way to build an object
    static function logger make_error_logger();
      logger l = new("ERROR");
      return l;
    endfunction
  endclass

  logger l1, l2;

  initial begin
    l1 = new();
    l1.log("start");
    l1.log("count", 5);
    l1.log("delay", 10, "ns");

    l2 = logger::make_error_logger();
    l2.log("mismatches", 3);
  end

endmodule
