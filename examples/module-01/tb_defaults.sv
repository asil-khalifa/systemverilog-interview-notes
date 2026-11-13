module tb_defaults;

  typedef enum {LOW, HIGH} level_e;

  class dummy;
  endclass

  bit       v_bit;
  logic     v_logic;
  int       v_int;
  integer   v_integer;
  real      v_real;
  string    v_string;
  wire      v_wire;
  level_e   v_enum;
  int       v_dyn [];
  int       v_queue [$];
  int       v_assoc [string];
  dummy     v_handle;
  struct { int a; logic [3:0] b; } v_struct;

  initial begin
    $display("bit=%b logic=%b int=%0d integer=%0d real=%0.1f",
             v_bit, v_logic, v_int, v_integer, v_real);
    $display("string='%s' (length %0d)", v_string, v_string.len());
    $display("wire=%b", v_wire);
    $display("enum=%s", v_enum.name());
    $display("dynamic array size=%0d  queue size=%0d  associative array entries=%0d",
             v_dyn.size(), v_queue.size(), v_assoc.num());
    if (v_handle == null) $display("class handle is null");
    $display("struct: a=%0d b=%b", v_struct.a, v_struct.b);
  end

endmodule
