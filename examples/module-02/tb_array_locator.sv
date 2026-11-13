module tb_array_locator;

  int d [] = '{4, 9, 2, 9, 7, 2, 5};
  int r  [$];          // for returned elements
  int ix [$];          // for returned indices

  initial begin
    r  = d.find with (item > 5);              $display("1.  find > 5             : %p", r);
    ix = d.find_index with (item > 5);        $display("2.  find_index > 5       : %p", ix);
    r  = d.find_first with (item > 5);        $display("3.  find_first > 5       : %p", r);
    ix = d.find_first_index with (item > 5);  $display("4.  find_first_index > 5 : %p", ix);
    r  = d.find_last with (item < 5);         $display("5.  find_last < 5        : %p", r);
    ix = d.find_last_index with (item < 5);   $display("6.  find_last_index < 5  : %p", ix);

    r  = d.find with (item > 100);
    $display("7.  find > 100           : size %0d", r.size());

    r  = d.min();                             $display("8.  min                  : %p", r);
    r  = d.max();                             $display("9.  max                  : %p", r);

    r  = d.unique();
    r.sort();                                 $display("10. unique (sorted)      : %p", r);
    ix = d.unique_index();
    $display("11. unique_index         : size %0d", ix.size());

    r  = d.find with (item.index >= 4);       $display("12. index >= 4           : %p", r);
    r  = d.find(x) with (x % 2 == 0);         $display("13. even values          : %p", r);

    ix = d.find_index with (item == 9);
    $display("14. the value 9 occurs %0d times, first at index %0d", ix.size(), ix[0]);
  end

endmodule
