package cfg_pkg;
  parameter int MAX_LEN = 16;
  function automatic int twice(int v);
    return 2 * v;
  endfunction
endpackage

class packet;
  typedef enum {SHORT, LONG} kind_e;      // a type declared inside the class
  localparam int HDR_LEN = 4;             // a constant declared inside the class
  static int count = 0;                   // one copy for the whole class

  kind_e kind;
  int    len;

  extern function new(kind_e kind, int len);
  extern function void print();

  static function int get_count();
    return count;
  endfunction
endclass

function packet::new(kind_e kind, int len);      // constructor defined outside the class
  this.kind = kind;
  this.len  = len;
  count++;
endfunction

function void packet::print();                    // method defined outside the class
  $display("   packet kind=%s len=%0d", kind.name(), len);
endfunction

module tb_scope_resolution;

  packet         p;
  packet::kind_e k;       // class-scoped type
  int            v;

  initial begin
    $display("1. cfg_pkg::MAX_LEN = %0d, cfg_pkg::twice(5) = %0d",
             cfg_pkg::MAX_LEN, cfg_pkg::twice(5));
    $display("2. packet::count = %0d, packet::HDR_LEN = %0d",
             packet::count, packet::HDR_LEN);

    k = packet::LONG;                   // class-scoped enum label
    p = new(k, 12);
    p = new(packet::SHORT, 3);
    p.print();
    $display("3. packet::get_count() = %0d", packet::get_count());

    void'(std::randomize(v) with { v inside {[1:3]}; });
    $display("4. v is in the range 1 to 3: %b", v inside {[1:3]});
  end

endmodule
