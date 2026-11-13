# Output-Prediction Questions

For each program, write down the exact output before reading the answer. Go statement by statement and keep track of the state. Every program here has one defined result: parallel threads use different delays, and no unseeded random values are printed.

## Arrays and Strings

**Q147. Queue operations.**

```systemverilog
module q147;
  int q [$] = '{1, 2, 3};
  initial begin
    q.push_back(4);
    q.push_front(0);
    q.insert(2, 9);
    void'(q.pop_back());
    q.delete(1);
    $display("%0d %0d %0d %0d size=%0d", q[0], q[1], q[2], q[3], q.size());
    $display("%0d %0d", q[$], q[$-1]);
  end
endmodule
```

Answer:

```output
0 9 2 3 size=4
3 2
```

The queue goes through these states: {1,2,3} → push_back(4) {1,2,3,4} → push_front(0) {0,1,2,3,4} → insert(2,9) {0,1,9,2,3,4} → pop_back {0,1,9,2,3} → delete(1) {0,9,2,3}. `q[$]` is the last element and `q[$-1]` the one before it.

**Q148. Dynamic array allocation.**

```systemverilog
module q148;
  int d [];
  initial begin
    d = new[3];
    foreach (d[i]) d[i] = i + 1;
    d = new[5](d);
    $display("%0d %0d %0d", d.size(), d[2], d[4]);
    d = new[2];
    $display("%0d %0d", d.size(), d[0]);
  end
endmodule
```

Answer:

```output
5 3 0
2 0
```

`new[5](d)` allocates five elements and copies the old three: {1,2,3,0,0}. `new[2]` without the copy argument allocates a fresh array filled with the default value 0; the old contents are discarded.

**Q149. Associative array iteration.**

```systemverilog
module q149;
  int    aa [string];
  string k;
  initial begin
    aa["b"] = 2;
    aa["a"] = 1;
    aa["c"] = 3;
    aa.delete("b");
    if (aa.first(k))
      do $display("%s=%0d", k, aa[k]);
      while (aa.next(k));
    $display("%0d %0d", aa.num(), aa.exists("b"));
  end
endmodule
```

Answer:

```output
a=1
c=3
2 0
```

Entries are visited in the sorted order of the index, not the order of insertion. After the delete only two entries remain and `exists("b")` is 0.

**Q150. Array locator and ordering methods.**

```systemverilog
module q150;
  int a [5] = '{4, 1, 3, 1, 5};
  int r [$];
  initial begin
    r = a.find with (item > 2);
    $display("%0d: %0d %0d %0d", r.size(), r[0], r[1], r[2]);
    r = a.find_index with (item == 1);
    $display("%0d %0d", r[0], r[1]);
    r = a.unique();
    $display("%0d", r.size());
    r = a.max();
    $display("%0d %0d", r[0], a.sum());
    a.rsort();
    $display("%0d %0d", a[0], a[4]);
  end
endmodule
```

Answer:

```output
3: 4 3 5
1 3
4
5 14
5 1
```

`find` returns the matching elements in index order. `find_index` returns the indices of the two 1s. `unique` returns one copy of each distinct value: 4, 1, 3, 5. `max` returns a queue with one element. The sum is 14. `rsort` sorts in descending order: {5,4,3,1,1}.

**Q151. The width of `sum()`.**

```systemverilog
module q151;
  bit [7:0] b [4] = '{200, 100, 50, 10};
  initial begin
    $display("%0d", b.sum());
    $display("%0d", b.sum() with (int'(item)));
    $display("%0d", b.sum() with (int'(item > 60)));
  end
endmodule
```

Answer:

```output
104
360
2
```

`sum()` has the type of the elements, 8 bits, so 360 wraps to 104. Casting each element to `int` makes the sum 32 bits wide. The last line counts the elements greater than 60 (200 and 100).

**Q152. String methods.**

```systemverilog
module q152;
  string s = "Hello";
  string n = "42abc";
  initial begin
    s = {s, " SV"};
    $display("%0d|%s|%s|%0d", s.len(), s.toupper(), s.substr(0, 3), s.compare("Hello SV"));
    $display("%0d %0d %s", s == "hello sv", n.atoi(), s);
  end
endmodule
```

Answer:

```output
8|HELLO SV|Hell|0
0 42 Hello SV
```

Concatenation gives "Hello SV", 8 characters. `toupper()` returns a new string and does not change `s`. `substr(0, 3)` returns characters 0 to 3 inclusive. `compare` returns 0 for equal strings. String comparison is case-sensitive. `atoi()` converts the leading decimal digits and stops at the first other character.

## Tasks and Functions

**Q153. Static and automatic variables.**

```systemverilog
module q153;
  function void count_s();
    static int c = 0;
    c++;
    $display("s=%0d", c);
  endfunction

  function automatic void count_a();
    int c = 0;
    c++;
    $display("a=%0d", c);
  endfunction

  initial repeat (3) begin
    count_s();
    count_a();
  end
endmodule
```

Answer:

```output
s=1
a=1
s=2
a=1
s=3
a=1
```

The static variable is created and initialised once, before simulation starts, and keeps its value between calls. The automatic variable is created and initialised on every call.

**Q154. Passing by value and by reference.**

```systemverilog
module q154;
  function automatic void by_val(int x);        x = x + 10;  endfunction
  function automatic void by_ref(ref int x);    x = x + 10;  endfunction
  function automatic void arr_val(int a [3]);   a[0] = 99;   endfunction
  function automatic void arr_ref(ref int a [3]); a[0] = 99; endfunction

  int v = 1;
  int arr [3] = '{1, 2, 3};

  initial begin
    by_val(v);     $display("%0d", v);
    by_ref(v);     $display("%0d", v);
    arr_val(arr);  $display("%0d", arr[0]);
    arr_ref(arr);  $display("%0d", arr[0]);
  end
endmodule
```

Answer:

```output
1
11
1
99
```

An argument with no direction is an `input`: the routine works on a copy, for scalars and for whole arrays. With `ref` the routine works on the caller's variable.

## Classes

**Q155. Handle assignment and copy.**

```systemverilog
module q155;
  class pkt;
    int data;
  endclass

  pkt p1, p2, p3;

  initial begin
    p1 = new();
    p1.data = 5;
    p2 = p1;
    p2.data = 7;
    p3 = new p1;
    p3.data = 9;
    $display("%0d %0d %0d", p1.data, p2.data, p3.data);
    $display("%b %b", p1 == p2, p1 == p3);
  end
endmodule
```

Answer:

```output
7 7 9
1 0
```

`p2 = p1` copies the handle, so `p1` and `p2` are the same object and the write through `p2` is seen through `p1`. `new p1` creates a second object with a copy of the data. `==` on handles compares whether they refer to the same object.

**Q156. Shallow copy with a nested object.**

```systemverilog
module q156;
  class hdr;
    int id;
  endclass

  class pkt;
    int len;
    hdr h;
    function new();
      h = new();
    endfunction
  endclass

  pkt a, b;

  initial begin
    a = new();
    a.len  = 1;
    a.h.id = 10;
    b = new a;
    b.len  = 2;
    b.h.id = 20;
    $display("a: len=%0d id=%0d", a.len, a.h.id);
    $display("b: len=%0d id=%0d", b.len, b.h.id);
  end
endmodule
```

Answer:

```output
a: len=1 id=20
b: len=2 id=20
```

The shallow copy duplicates `len` but copies only the handle `h`, so both packets share one `hdr` object. Changing `b.h.id` changes what `a.h.id` reads. A deep copy would need `b.h = new a.h;`.

**Q157. Virtual and non-virtual methods.**

```systemverilog
module q157;
  class base;
    function void show();          $display("base show");   endfunction
    virtual function void vshow(); $display("base vshow");  endfunction
  endclass

  class child extends base;
    function void show();          $display("child show");  endfunction
    virtual function void vshow(); $display("child vshow"); endfunction
  endclass

  base  b;
  child c;

  initial begin
    c = new();
    b = c;
    b.show();
    b.vshow();
    c.show();
  end
endmodule
```

Answer:

```output
base show
child vshow
child show
```

`show` is not virtual, so the type of the handle (`base`) selects the method. `vshow` is virtual, so the type of the object (`child`) selects it. Through the `child` handle the child's `show` is called.

**Q158. Constructor order.**

```systemverilog
module q158;
  class A;
    function new();
      $display("A new");
    endfunction
  endclass

  class B extends A;
    int x = 5;
    function new();
      $display("B new x=%0d", x);
      x = 7;
    endfunction
  endclass

  class C extends B;
    function new();
      super.new();
      $display("C new x=%0d", x);
    endfunction
  endclass

  C c;
  initial c = new();
endmodule
```

Answer:

```output
A new
B new x=5
C new x=7
```

Construction runs from the base class down. `B` has no explicit `super.new()`, so the compiler inserts one. The declaration initialiser `x = 5` is applied after `A`'s constructor returns and before the body of `B`'s constructor.

**Q159. Static property.**

```systemverilog
module q159;
  class counter;
    static int count;
    int        id;
    function new();
      count++;
      id = count;
    endfunction
  endclass

  counter a, b, c;

  initial begin
    $display("%0d", counter::count);
    a = new();
    b = new();
    c = new a;
    $display("%0d %0d %0d %0d", a.id, b.id, c.id, counter::count);
  end
endmodule
```

Answer:

```output
0
1 2 1 2
```

The static property exists before any object does. `a` and `b` each run the constructor. `c = new a` is a shallow copy: it does not run the constructor, so `count` stays 2 and `c.id` is a copy of `a.id`.

**Q160. Property hiding and `super`.**

```systemverilog
module q160;
  class base;
    int x = 1;
    virtual function int get();
      return x;
    endfunction
  endclass

  class child extends base;
    int x = 2;
    virtual function int get();
      return x + super.get();
    endfunction
  endclass

  base  b;
  child c;

  initial begin
    c = new();
    b = c;
    $display("%0d %0d %0d", b.x, c.x, b.get());
  end
endmodule
```

Answer:

```output
1 2 3
```

The child object contains two properties called `x`. Property access depends on the handle type: `b.x` is the base property (1) and `c.x` is the child property (2). `get` is virtual, so `b.get()` runs the child version: its own `x` (2) plus the base method's result (1).

**Q161. Downcasting.**

```systemverilog
module q161;
  class base;
  endclass

  class child extends base;
    int extra = 5;
  endclass

  base  b;
  child c;

  initial begin
    b = new();
    if ($cast(c, b)) $display("cast 1 ok");
    else             $display("cast 1 failed, c is null: %b", c == null);

    c = new();
    b = c;
    c = null;
    if ($cast(c, b)) $display("cast 2 ok, extra=%0d", c.extra);
    else             $display("cast 2 failed");
  end
endmodule
```

Answer:

```output
cast 1 failed, c is null: 1
cast 2 ok, extra=5
```

In the first case the object is a plain `base`; it has no `extra` property, so it cannot be referred to by a `child` handle and `$cast` returns 0, leaving `c` unchanged. In the second case the object is a `child` referred to by a base handle, so the downcast succeeds.

## Threads and Communication

**Q162. `join_any`, `join_none` and `wait fork`.**

```systemverilog
module q162;
  initial begin
    fork
      #10 $display("[%0t] A", $time);
      #20 $display("[%0t] B", $time);
    join_any
    $display("[%0t] after join_any", $time);
    fork
      #5 $display("[%0t] C", $time);
    join_none
    $display("[%0t] after join_none", $time);
    wait fork;
    $display("[%0t] done", $time);
  end
endmodule
```

Answer:

```output
[10] A
[10] after join_any
[10] after join_none
[15] C
[20] B
[20] done
```

`join_any` releases the parent when the first thread (A) finishes at time 10; B keeps running. `join_none` does not block, so the next line prints at time 10. `wait fork` blocks until C (time 15) and B (time 20) have both finished.

**Q163. Threads created in a loop.**

```systemverilog
module q163;
  initial begin
    for (int i = 0; i < 3; i++)
      fork
        $display("A: i=%0d", i);
      join_none
    #1;
    for (int i = 0; i < 3; i++)
      fork
        automatic int k = i;
        #(k + 1) $display("[%0t] B: k=%0d", $time, k);
      join_none
    wait fork;
    $display("[%0t] done", $time);
  end
endmodule
```

Answer:

```output
A: i=3
A: i=3
A: i=3
[2] B: k=0
[3] B: k=1
[4] B: k=2
[4] done
```

The first three threads do not start until the parent blocks at `#1`, by which time the loop has finished and the shared `i` is 3. In the second loop each thread has its own `k`, initialised when the thread is created. The threads are created at time 1 and wait 1, 2 and 3 time units.

**Q164. `disable fork`.**

```systemverilog
module q164;
  initial begin
    fork
      begin #10 $display("[%0t] T1 done", $time); end
      begin #30 $display("[%0t] T2 done", $time); end
    join_any
    disable fork;
    #50 $display("[%0t] end", $time);
  end
endmodule
```

Answer:

```output
[10] T1 done
[60] end
```

T1 finishes at time 10 and releases `join_any`. `disable fork` kills T2, which never prints. The parent then waits 50 more time units.

**Q165. A bounded mailbox.**

```systemverilog
module q165;
  mailbox #(int) mbx = new(2);

  initial
    for (int i = 1; i <= 3; i++) begin
      mbx.put(i);
      $display("[%0t] put %0d", $time, i);
    end

  initial begin
    int v;
    #10;
    repeat (3) begin
      mbx.get(v);
      $display("[%0t] got %0d", $time, v);
      #10;
    end
  end
endmodule
```

Answer:

```output
[0] put 1
[0] put 2
[10] got 1
[10] put 3
[20] got 2
[30] got 3
```

The mailbox holds two items, so the third `put` blocks at time 0. At time 10 the consumer removes one item and prints; when it then blocks at `#10`, the producer runs, completes its `put` and prints. Items come out in the order they went in.

**Q166. `@e` compared with `wait (e.triggered)`.**

```systemverilog
module q166;
  event e;
  initial begin
    #10 -> e;
    fork
      begin @e;                 $display("[%0t] @e returned", $time);   end
      begin wait (e.triggered); $display("[%0t] wait returned", $time); end
    join_any
    $display("[%0t] after join_any", $time);
    #20 $display("[%0t] the @e thread is still blocked", $time);
  end
endmodule
```

Answer:

```output
[10] wait returned
[10] after join_any
[30] the @e thread is still blocked
```

The event is triggered at time 10 before either thread starts waiting. `e.triggered` stays true until the end of time step 10, so the `wait` passes at once. `@e` waits for a new trigger, which never comes, so that thread blocks for the rest of the simulation.

**Q167. A semaphore with one key.**

```systemverilog
module q167;
  semaphore sem = new(1);

  task automatic user(string name, int hold);
    sem.get(1);
    $display("[%0t] %s got the key", $time, name);
    #hold;
    sem.put(1);
  endtask

  initial begin
    fork
      user("A", 10);
      #1 user("B", 5);
    join
    $display("[%0t] both finished", $time);
  end
endmodule
```

Answer:

```output
[0] A got the key
[10] B got the key
[15] both finished
```

A takes the only key at time 0. B asks at time 1 and blocks until A returns the key at time 10. B holds it for 5 time units, and `join` waits for both.

## Assignments and Randomization

**Q168. Blocking and nonblocking assignments.**

```systemverilog
module q168;
  logic [3:0] a = 1, b = 2, c = 3, d = 4;
  initial begin
    a = b;
    b = a;
    c <= d;
    d <= c;
    $display("%0d %0d %0d %0d", a, b, c, d);
    #1 $display("%0d %0d %0d %0d", a, b, c, d);
  end
endmodule
```

Answer:

```output
2 2 3 4
2 2 4 3
```

The blocking assignments take effect immediately: `a` becomes 2, then `b` is assigned the new `a`, also 2. The nonblocking assignments read the old `c` and `d` but have not updated them when the first `$display` runs. After the NBA region, `c` and `d` are swapped.

**Q169. Does `randomize()` succeed, and with what values?**

```systemverilog
module q169;
  class pair;
    rand bit [3:0] a, b;
    constraint c { a < 3; b < 3; a > b; a + b == 3; }
  endclass

  pair p;
  int  ok;

  initial begin
    p  = new();
    ok = p.randomize();
    $display("%0d %0d %0d", ok, p.a, p.b);
    ok = p.randomize() with { b == 2; };
    $display("%0d %0d %0d", ok, p.a, p.b);
  end
endmodule
```

Answer:

```output
1 2 1
0 2 1
```

Both variables must be 0, 1 or 2, `a` must be greater than `b`, and the sum must be 3. The only solution is `a` = 2, `b` = 1, so the first call always produces it. The inline constraint `b == 2` would need `a` > 2, which contradicts `a < 3`: the call returns 0 and the variables keep their previous values. (The simulator also prints a constraint-failure warning.)

**Q170. `rand_mode()` and `constraint_mode()`.**

```systemverilog
module q170;
  class cfg;
    rand bit [3:0] x, y;
    constraint lim { x == 5; y == x + 1; }
  endclass

  cfg c;
  int ok;

  initial begin
    c  = new();
    ok = c.randomize();
    $display("%0d %0d %0d", ok, c.x, c.y);

    c.y.rand_mode(0);
    c.y = 9;
    ok  = c.randomize();
    $display("%0d %0d %0d", ok, c.x, c.y);

    c.lim.constraint_mode(0);
    c.x.rand_mode(0);
    ok = c.randomize();
    $display("%0d %0d %0d", ok, c.x, c.y);
  end
endmodule
```

Answer:

```output
1 5 6
0 5 9
1 5 9
```

First call: `x` = 5 forces `y` = 6. Second call: `y` is no longer random, so it is a fixed value 9 that must still satisfy `y == x + 1`; that needs `x` = 8, which contradicts `x == 5`, so the call fails and nothing changes. Third call: the constraint block is off and neither variable is random, so there is nothing to solve and nothing to violate; the call succeeds and the values stay as they are.

> **Interview trap:** Switching off `rand_mode` does not remove a variable from the constraints. It turns the variable into a constant that the constraints must still accept. This is the difference from `constraint_mode(0)`, which removes the constraint.
