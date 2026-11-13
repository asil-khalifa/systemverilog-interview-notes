module tb_static_method;

  class id_gen;
    local static int next_id = 100;       // hidden shared state
    int              calls;               // an ordinary, per-object property

    static function int get_id();
      int id;
      id = next_id;
      next_id++;
      // calls++;                         // ILLEGAL: non-static property in a static method
      // this.calls = 0;                  // ILLEGAL: no "this" in a static method
      return id;
    endfunction

    static function void reset(int start = 100);
      next_id = start;
    endfunction
  endclass

  id_gen g;                               // never constructed in this example

  initial begin
    $display("1. %0d", id_gen::get_id());
    $display("2. %0d", id_gen::get_id());
    $display("3. %0d", g.get_id());       // legal even though g is null
    id_gen::reset(500);
    $display("4. %0d", id_gen::get_id());
  end

endmodule
