module ex01_rotate;

  int arr [5] = '{1, 2, 3, 4, 5};
  int rot [5];
  int q [$];
  int k = 2;

  initial begin
    // 1. index arithmetic: element i of the result comes from index (i + k) modulo size
    foreach (arr[i]) rot[i] = arr[(i + k) % $size(arr)];
    $display("fixed array : %p", rot);

    // 2. queue: move the front element to the back, k times
    q = arr;
    repeat (k) q.push_back(q.pop_front());
    $display("queue       : %p", q);
  end

endmodule
