package util_pkg;

  parameter int DATA_W = 8;

  typedef logic [DATA_W-1:0]       data_t;
  typedef enum {LOW, MEDIUM, HIGH} level_e;

  int unsigned error_count = 0;            // ONE copy, shared by every user of the package

  function automatic data_t swap_nibbles(data_t d);
    return {d[3:0], d[7:4]};
  endfunction

  function automatic void report_error(string msg);
    error_count++;
    $display("ERROR %0d: %s", error_count, msg);
  endfunction

  class counter;
    static int created = 0;
    int        id;
    function new();
      created++;
      id = created;
    endfunction
  endclass

endpackage : util_pkg

module tb_package_basic;
  import util_pkg::*;

  data_t  d;
  level_e lvl;
  counter c1, c2;

  initial begin
    d = swap_nibbles(8'hA5);
    $display("1. swap_nibbles(A5) = %h, DATA_W = %0d", d, DATA_W);

    lvl = HIGH;
    $display("2. lvl = %s", lvl.name());

    report_error("first problem");
    util_pkg::report_error("second problem");
    $display("3. error_count = %0d", util_pkg::error_count);

    c1 = new();
    c2 = new();
    $display("4. c2.id = %0d, counter::created = %0d", c2.id, counter::created);
  end

endmodule
