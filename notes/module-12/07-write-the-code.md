# Write-the-Code Questions

These are the short programs interviewers ask you to write in a shared editor. Aim to write each one in under ten minutes. State your assumptions aloud, write the simplest correct version first, then mention improvements.

## Arrays and Basic Logic

**Q203. Reverse a queue without using `reverse()`.**

```systemverilog
module q203;
  int q [$] = '{1, 2, 3, 4, 5};
  int r [$];
  int tmp;

  initial begin
    // Method 1: in place, swapping from both ends
    for (int i = 0, j = q.size() - 1; i < j; i++, j--) begin
      tmp  = q[i];
      q[i] = q[j];
      q[j] = tmp;
    end
    $display("%p", q);                    // 5 4 3 2 1

    // Method 2: pop from the back of one queue, push to the back of another
    while (q.size() > 0) r.push_back(q.pop_back());
    $display("%p", r);                    // 1 2 3 4 5 again
  end
endmodule
```

Points to mention: a `for` loop may declare and update two variables; method 2 empties the source queue.

**Q204. Remove duplicate values from a queue, keeping the first occurrence of each and the original order.**

```systemverilog
module q204;
  int q [$] = '{3, 7, 3, 1, 7, 9, 1};
  int r [$];
  bit seen [int];                         // associative array used as a set

  initial begin
    foreach (q[i])
      if (!seen.exists(q[i])) begin
        seen[q[i]] = 1;
        r.push_back(q[i]);
      end
    $display("%p", r);                    // 3 7 1 9
  end
endmodule
```

`q.unique()` also returns the distinct values, but the standard does not promise that it keeps the original order, so the explicit loop is the safe answer. The associative array makes the membership test fast.

**Q205. Find the second largest distinct value in an array.**

```systemverilog
module q205;
  int a [] = '{4, 9, 2, 9, 7};
  int big, second;
  bit found;

  initial begin
    big = a[0];
    foreach (a[i]) begin
      if (a[i] > big) begin
        second = big;
        big    = a[i];
        found  = 1;
      end
      else if (a[i] != big && (!found || a[i] > second)) begin
        second = a[i];
        found  = 1;
      end
    end
    if (found) $display("largest=%0d second=%0d", big, second);   // 9 and 7
    else       $display("all elements are equal");
  end
endmodule
```

One pass, no sorting. The `found` flag handles an array whose elements are all equal. The shorter alternative, acceptable if speed does not matter: `r = a.unique(); r.rsort();` and take `r[1]`.

**Q206. Count how many times each value occurs in an array.**

```systemverilog
module q206;
  int data [] = '{5, 3, 5, 8, 3, 5};
  int count [int];                        // key = value, entry = number of occurrences

  initial begin
    foreach (data[i])
      if (count.exists(data[i])) count[data[i]]++;
      else                       count[data[i]] = 1;
    foreach (count[k]) $display("%0d occurs %0d times", k, count[k]);
  end
endmodule
```

```output
3 occurs 2 times
5 occurs 3 times
8 occurs 1 times
```

The associative array is iterated in ascending key order. Many engineers write just `count[data[i]]++;`, relying on a new entry starting at 0; the explicit `exists` test avoids any warning about reading an entry that does not exist.

**Q207. Swap two variables without a temporary variable.**

```systemverilog
module q207;
  logic [7:0] a = 8'h3C, b = 8'hA5;
  initial begin
    {a, b} = {b, a};                      // 1. concatenation: RHS is evaluated first
    a = a ^ b;  b = a ^ b;  a = a ^ b;    // 2. XOR swap (swaps back)
    a = a + b;  b = a - b;  a = a - b;    // 3. arithmetic swap (wraps correctly)
    $display("%h %h", a, b);              // a5 3c after three swaps
    a <= b;  b <= a;                      // 4. nonblocking assignments
    #1 $display("%h %h", a, b);           // 3c a5
  end
endmodule
```

Method 1 is the idiomatic answer. Method 4 is how two registers are swapped in RTL.

**Q208. Write a clock generator with a parameterised frequency and duty cycle.**

```systemverilog
`timescale 1ns/1ps

module clk_gen #(
  parameter real FREQ_MHZ = 100.0,
  parameter real DUTY_PCT = 40.0
) (
  output logic clk
);
  real period_ns, t_high, t_low;

  initial begin
    period_ns = 1000.0 / FREQ_MHZ;            // 100 MHz -> 10 ns
    t_high    = period_ns * DUTY_PCT / 100.0; // 4 ns high
    t_low     = period_ns - t_high;           // 6 ns low
    clk = 1'b0;
    forever begin
      #t_low  clk = 1'b1;
      #t_high clk = 1'b0;
    end
  end
endmodule
```

Mention that the time precision (1 ps here) limits the accuracy: a period that is not a multiple of the precision is rounded.

**Q209. Write a detector for the serial bit sequence 1011, with overlapping sequences allowed.**

```systemverilog
module seq_det_1011 (
  input  logic clk, rst_n, din,
  output logic det
);
  typedef enum logic [1:0] {S0, S1, S10, S101} state_e;
  state_e state, next_state;

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) state <= S0;
    else        state <= next_state;

  always_comb begin
    next_state = S0;
    unique case (state)
      S0  : next_state = din ? S1   : S0;
      S1  : next_state = din ? S1   : S10;
      S10 : next_state = din ? S101 : S0;
      S101: next_state = din ? S1   : S10;   // overlap: the last 1 starts a new match
    endcase
  end

  assign det = (state == S101) && din;        // Mealy output
endmodule
```

Each state name records how much of the pattern has been seen. From `S101`, an input of 1 completes the pattern and leaves "1" as the start of the next one; an input of 0 leaves "10". For the stream 1011011, `det` is 1 at the fourth and the seventh bit. Without overlap, `S101` with `din` = 1 would return to `S0`.

**Q210. Write a circuit that detects rising and falling edges of a signal.**

```systemverilog
module edge_det (
  input  logic clk, rst_n, sig,
  output logic rise, fall, any_edge
);
  logic sig_q;                                // sig delayed by one clock

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) sig_q <= 1'b0;
    else        sig_q <= sig;

  assign rise     =  sig & ~sig_q;            // 0 -> 1
  assign fall     = ~sig &  sig_q;            // 1 -> 0
  assign any_edge =  sig ^  sig_q;
endmodule
```

Each output is a one-cycle pulse. If `sig` comes from another clock domain it must first pass through a two-flop synchroniser.

**Q211. Write recursive factorial and an iterative check for a palindrome string.**

```systemverilog
module q211;
  function automatic longint unsigned fact(int unsigned n);
    return (n <= 1) ? 1 : n * fact(n - 1);
  endfunction

  function automatic bit is_palindrome(string s);
    for (int i = 0, j = s.len() - 1; i < j; i++, j--)
      if (s[i] != s[j]) return 0;
    return 1;
  endfunction

  initial begin
    $display("%0d %0d", fact(5), fact(0));                       // 120 1
    $display("%b %b", is_palindrome("level"), is_palindrome("sv")); // 1 0
  end
endmodule
```

The function must be `automatic` to be recursive in a module: a static function has a single copy of `n`, which the nested calls would overwrite.

## Classes

**Q212. Write a singleton class.**

```systemverilog
class tb_config;
  local static tb_config inst;            // the one object
  int unsigned num_txn = 10;

  local function new();                   // nobody outside the class can construct it
  endfunction

  static function tb_config get();
    if (inst == null) inst = new();
    return inst;
  endfunction
endclass

module q212;
  tb_config c1, c2;
  initial begin
    c1 = tb_config::get();
    c2 = tb_config::get();
    c1.num_txn = 50;
    $display("%0d %b", c2.num_txn, c1 == c2);      // 50 1
  end
endmodule
```

A singleton guarantees that exactly one object of the class exists and gives global access to it. The three ingredients are a static handle, a `local` constructor and a static `get()` function. It is used for a shared configuration or report object.

**Q213. Write a class with a nested object and a correct deep copy.**

```systemverilog
class pkt_hdr;
  bit [7:0] src, dst;
  function pkt_hdr copy();
    pkt_hdr c = new();
    c.src = src;
    c.dst = dst;
    return c;
  endfunction
endclass

class packet;
  pkt_hdr   hdr;
  bit [7:0] payload [];

  function new();
    hdr = new();
  endfunction

  virtual function packet copy();
    packet c  = new();
    c.hdr     = hdr.copy();               // nested object: copy it, not the handle
    c.payload = payload;                  // dynamic array: assignment copies the elements
    return c;
  endfunction
endclass
```

Say explicitly which members need care: handles do (they would be shared), arrays of plain values do not (array assignment copies the data), arrays of handles do (each element must be copied).

**Q214. Write a parameterised stack class.**

```systemverilog
class stack #(type T = int, int DEPTH = 8);
  local T items [$];

  function bit push(T item);
    if (items.size() >= DEPTH) return 0;          // full
    items.push_back(item);
    return 1;
  endfunction

  function bit pop(output T item);
    if (items.size() == 0) return 0;              // empty
    item = items.pop_back();
    return 1;
  endfunction

  function int size();
    return items.size();
  endfunction
endclass

module q214;
  stack #(string, 2) s = new();
  string str;
  bit    ok_a, ok_b, ok_c;
  initial begin
    ok_a = s.push("a");
    ok_b = s.push("b");
    ok_c = s.push("c");                           // rejected: the stack is full
    $display("%b %b %b", ok_a, ok_b, ok_c);       // 1 1 0
    void'(s.pop(str));
    $display("%s %0d", str, s.size());            // b 1
  end
endmodule
```

Last in, first out: push and pop use the same end of the queue. Returning a status bit instead of printing an error lets the caller decide what a full or empty stack means.

## Threads and Communication

**Q215. Write a generator and a driver that communicate through a mailbox, where the generator waits for the driver to finish each item.**

```systemverilog
class generator;
  mailbox #(int) gen2drv_mbx;
  event          drv_done;
  int            n;

  function new(mailbox #(int) mbx, event drv_done, int n);
    this.gen2drv_mbx = mbx;
    this.drv_done    = drv_done;
    this.n           = n;
  endfunction

  task run();
    for (int i = 1; i <= n; i++) begin
      gen2drv_mbx.put(i);
      $display("[%0t] gen: sent %0d", $time, i);
      @drv_done;                          // wait until the driver has finished this item
    end
  endtask
endclass

class driver;
  mailbox #(int) gen2drv_mbx;
  event          drv_done;

  function new(mailbox #(int) mbx, event drv_done);
    this.gen2drv_mbx = mbx;
    this.drv_done    = drv_done;
  endfunction

  task run();
    int item;
    forever begin
      gen2drv_mbx.get(item);
      #10;                                // time taken to drive the item
      $display("[%0t] drv: drove %0d", $time, item);
      -> drv_done;
    end
  endtask
endclass

module q215;
  mailbox #(int) mbx = new();
  event          done;
  generator      gen;
  driver         drv;

  initial begin
    gen = new(mbx, done, 2);
    drv = new(mbx, done);
    fork
      gen.run();
      drv.run();
    join_any                              // the generator ends; the driver runs forever
    $display("[%0t] test finished", $time);
    $finish;
  end
endmodule
```

```output
[0] gen: sent 1
[10] drv: drove 1
[10] gen: sent 2
[20] drv: drove 2
[20] test finished
```

The mailbox and the event are created once in the top and the same handles are given to both objects. `@drv_done` is safe here because the driver triggers it 10 time units after the generator started waiting; if the driver could respond in zero time, `wait (drv_done.triggered)` would be needed.

**Q216. Two threads must write to the same bus. Protect the bus with a semaphore.**

```systemverilog
module q216;
  semaphore bus_key = new(1);

  task automatic bus_write(string who, int addr);
    bus_key.get(1);                               // wait for exclusive access
    $display("[%0t] %s starts write to %0h", $time, who, addr);
    #10;                                          // the transfer takes time
    $display("[%0t] %s ends write", $time, who);
    bus_key.put(1);                               // always give the key back
  endtask

  initial begin
    fork
      begin bus_write("seq_a", 'h10); #1; bus_write("seq_a", 'h14); end
      #1 bus_write("seq_b", 'h20);
    join
  end
endmodule
```

```output
[0] seq_a starts write to 10
[10] seq_a ends write
[10] seq_b starts write to 20
[20] seq_b ends write
[20] seq_a starts write to 14
[30] seq_a ends write
```

The transfers never overlap. `seq_b` has been waiting since time 1 and receives the key when `seq_a` returns it at time 10; `seq_a` asks again at time 11 and has to wait until time 20. Without the semaphore, the writes of the two threads would overlap from time 1 to time 10. (The `#1` between the two writes of `seq_a` is deliberate: if a thread returns the key and asks for it again in the same instant, simulators differ on whether it or the waiting thread gets the key.)

**Q217. Write a task that waits for a signal with a timeout.**

```systemverilog
module q217;
  logic done = 0;

  task automatic wait_done(input time timeout, output bit ok);
    ok = 0;
    fork
      begin                               // isolating process for disable fork
        fork
          begin @(posedge done); ok = 1; end
          #timeout;
        join_any
        disable fork;                     // kill whichever branch is still waiting
      end
    join
  endtask

  initial begin
    bit ok;
    fork
      #30 done = 1;
    join_none
    wait_done(100, ok);  $display("[%0t] ok=%b", $time, ok);   // [30] ok=1
    done = 0;
    wait_done(100, ok);  $display("[%0t] ok=%b", $time, ok);   // [130] ok=0
  end
endmodule
```

The pattern is `fork` two branches (the awaited condition and the delay), `join_any`, then `disable fork`. The outer `fork`...`join` with one `begin`...`end` makes sure `disable fork` cannot kill unrelated threads of the caller (here, the thread that sets `done`).

**Q218. Write a scoreboard that compares observed transactions with expected ones, in order.**

```systemverilog
class simple_scb;
  logic [8:0] exp_q [$];                  // expected results, oldest first
  int unsigned pass_cnt, fail_cnt;

  function void write_expected(logic [8:0] value);
    exp_q.push_back(value);
  endfunction

  function void write_actual(logic [8:0] value);
    logic [8:0] exp;
    if (exp_q.size() == 0) begin
      $error("unexpected output %0h: nothing was expected", value);
      fail_cnt++;
      return;
    end
    exp = exp_q.pop_front();
    if (value !== exp) begin
      $error("mismatch: actual=%0h expected=%0h", value, exp);
      fail_cnt++;
    end
    else pass_cnt++;
  endfunction

  function void report();
    if (exp_q.size() != 0) begin
      $error("%0d expected results never arrived", exp_q.size());
      fail_cnt += exp_q.size();
    end
    $display("scoreboard: %0d passed, %0d failed", pass_cnt, fail_cnt);
  endfunction
endclass
```

Three checks make a scoreboard complete, and interviewers look for all of them: the value comparison (with `!==`), an output that was not expected (empty queue), and expected items that never came out (non-empty queue at the end of the test).

**Q219. Start N parallel threads, each with its own ID, and wait until all have finished.**

```systemverilog
module q219;
  task automatic worker(int id);
    #(id * 10) $display("[%0t] worker %0d done", $time, id);
  endtask

  initial begin
    for (int i = 1; i <= 3; i++) begin
      fork
        automatic int id = i;             // one copy per thread
        worker(id);
      join_none
    end
    wait fork;                            // block until all three have finished
    $display("[%0t] all workers done", $time);
  end
endmodule
```

```output
[10] worker 1 done
[20] worker 2 done
[30] worker 3 done
[30] all workers done
```

`fork`...`join` cannot be used because the number of threads is decided by a loop; the combination `join_none` in a loop plus `wait fork` is the standard answer. The `automatic` copy is essential (see Q163).
