module tb_integer_types;

  bit      v_bit;
  logic    v_logic;
  byte     v_byte;
  shortint v_shortint;
  int      v_int;
  longint  v_longint;
  integer  v_integer;
  time     v_time;

  initial begin
    $display("--- default values ---");
    $display("bit=%b logic=%b byte=%0d shortint=%0d", v_bit, v_logic, v_byte, v_shortint);
    $display("int=%0d longint=%0d integer=%0d time=%0d", v_int, v_longint, v_integer, v_time);

    $display("--- width in bits ---");
    $display("bit=%0d logic=%0d byte=%0d shortint=%0d",
             $bits(v_bit), $bits(v_logic), $bits(v_byte), $bits(v_shortint));
    $display("int=%0d longint=%0d integer=%0d time=%0d",
             $bits(v_int), $bits(v_longint), $bits(v_integer), $bits(v_time));

    $display("--- overflow wraps around ---");
    v_byte = 127;          v_byte++;     $display("byte     127 + 1        = %0d", v_byte);
    v_shortint = 32767;    v_shortint++; $display("shortint 32767 + 1      = %0d", v_shortint);
    v_int = 2147483647;    v_int++;      $display("int      2147483647 + 1 = %0d", v_int);
    v_byte = 200;                        $display("byte     assigned 200   = %0d", v_byte);

    $display("--- four-state to two-state ---");
    v_integer = 'x;
    v_int     = v_integer;
    $display("integer=%0d copied into int=%0d", v_integer, v_int);
  end

endmodule
