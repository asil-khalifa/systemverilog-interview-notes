module tb_queue;

  int q [$];
  int x;

  initial begin
    q = {10, 20, 30};
    $display("1.  q = %p  size = %0d", q, q.size());

    q.push_back(40);          $display("2.  push_back(40)   : %p", q);
    q.push_front(5);          $display("3.  push_front(5)   : %p", q);

    x = q.pop_front();        $display("4.  pop_front -> %0d : %p", x, q);
    x = q.pop_back();         $display("5.  pop_back  -> %0d : %p", x, q);

    q.insert(1, 15);          $display("6.  insert(1, 15)   : %p", q);
    q.delete(2);              $display("7.  delete(2)       : %p", q);

    $display("8.  first = %0d  last = %0d  second-to-last = %0d", q[0], q[$], q[$-1]);

    q = {q, 50, 60};          $display("9.  {q, 50, 60}     : %p", q);
    q = q[1:3];               $display("10. q[1:3]          : %p", q);
    q = {q[0:0], 99, q[1:$]}; $display("11. insert by slice : %p", q);
    q[$+1] = 7;               $display("12. q[$+1] = 7      : %p", q);

    q.delete();               $display("13. delete()        : size = %0d", q.size());
    x = q.pop_front();        $display("14. pop from empty  : %0d", x);
  end

endmodule
