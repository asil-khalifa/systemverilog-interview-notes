class inorder_scoreboard #(type T = int);

  protected T  expected_q [$];
  int unsigned matches;
  int unsigned mismatches;
  string       name;

  function new(string name);
    this.name = name;
  endfunction

  function void add_expected(T item);
    expected_q.push_back(item);
  endfunction

  function void check_actual(T actual);
    T exp;
    if (expected_q.size() == 0) begin
      mismatches++;
      $display("[%s] FAIL: item %0d was not expected", name, matches + mismatches);
      return;
    end
    exp = expected_q.pop_front();
    if (actual == exp) matches++;
    else begin
      mismatches++;
      $display("[%s] FAIL: item %0d does not match", name, matches + mismatches);
    end
  endfunction

  function void report();
    $display("[%s] matches=%0d mismatches=%0d still expected=%0d",
             name, matches, mismatches, expected_q.size());
  endfunction

endclass

module tb_generic_scoreboard;

  typedef struct {
    bit [7:0] addr;
    bit [7:0] data;
  } bus_item_t;

  inorder_scoreboard #(int)        int_sb;
  inorder_scoreboard #(bus_item_t) bus_sb;
  bus_item_t item;

  initial begin
    int_sb = new("int_sb");
    bus_sb = new("bus_sb");

    int_sb.add_expected(5);
    int_sb.add_expected(6);
    int_sb.add_expected(7);
    int_sb.check_actual(5);
    int_sb.check_actual(9);
    int_sb.report();

    item = '{addr: 8'h10, data: 8'hAA};
    bus_sb.add_expected(item);
    bus_sb.check_actual(item);
    item.data = 8'hAB;
    bus_sb.check_actual(item);
    bus_sb.report();
  end

endmodule
