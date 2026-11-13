class stack #(type T = int, int DEPTH = 4);

  static int instances = 0;
  local  T   items [$];

  function new();
    instances++;
  endfunction

  function bit push(T item);
    if (items.size() >= DEPTH) return 0;      // full
    items.push_back(item);
    return 1;
  endfunction

  function bit pop(output T item);
    if (items.size() == 0) return 0;          // empty
    item = items.pop_back();
    return 1;
  endfunction

  function int size();
    return items.size();
  endfunction

endclass

module tb_param_class;

  typedef stack #(string, 2) str_stack_t;

  stack           int_stk;      // default specialisation: T = int, DEPTH = 4
  stack #(int, 4) int_stk2;     // the same type as int_stk
  str_stack_t     str_stk;

  int    i;
  string s;

  initial begin
    int_stk  = new();
    int_stk2 = new();
    str_stk  = new();

    for (int k = 1; k <= 5; k++)
      if (!int_stk.push(k * 10)) $display("1. push(%0d) rejected: stack is full", k * 10);

    void'(int_stk.pop(i));
    $display("2. popped %0d, size is now %0d", i, int_stk.size());

    void'(str_stk.push("alpha"));
    void'(str_stk.push("beta"));
    if (!str_stk.push("gamma")) $display("3. push(gamma) rejected: DEPTH is 2");
    void'(str_stk.pop(s));
    $display("4. popped %s", s);

    $display("5. stack #(int, 4)::instances = %0d", stack #(int, 4)::instances);
    $display("6. str_stack_t::instances     = %0d", str_stack_t::instances);

    int_stk2 = int_stk;         // legal: both handles have the same specialisation
    // str_stk = int_stk;       // ILLEGAL: different specialisations are different types
  end

endmodule
