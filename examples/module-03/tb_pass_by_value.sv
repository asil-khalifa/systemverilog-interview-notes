module tb_pass_by_value;

  int data [4] = '{1, 2, 3, 4};
  int n;

  function automatic void try_change(int v);
    v = 99;                                   // changes the copy
  endfunction

  function automatic void clear_copy(int arr [4]);
    foreach (arr[i]) arr[i] = 0;              // clears the copy
  endfunction

  function automatic void clear_ref(ref int arr [4]);
    foreach (arr[i]) arr[i] = 0;              // clears the caller's array
  endfunction

  function automatic int total(const ref int arr [4]);
    int sum;
    sum = 0;
    foreach (arr[i]) sum += arr[i];
    return sum;
  endfunction

  function automatic void show(string label);
    $display("%s: %0d %0d %0d %0d  total=%0d", label,
             data[0], data[1], data[2], data[3], total(data));
  endfunction

  initial begin
    n = 5;
    try_change(n);
    $display("n after try_change = %0d", n);

    show("initial         ");
    clear_copy(data);
    show("after clear_copy");
    clear_ref(data);
    show("after clear_ref ");
  end

endmodule
