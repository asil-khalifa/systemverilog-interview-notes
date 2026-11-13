module tb_array_ordering;

  typedef struct {
    int id;
    int len;
  } pkt_t;

  int    d [] = '{4, 9, 2, 9, 7, 2, 5};
  int    copy [];
  string names [$] = {"ravi", "anu", "zoya", "maya"};
  pkt_t  pkts [4] = '{ '{1, 12}, '{2, 64}, '{3, 3}, '{4, 30} };

  initial begin
    copy = d;                       // keep the original order
    d.sort();                       $display("1. sort     : %p", d);
    d.rsort();                      $display("2. rsort    : %p", d);
    d.reverse();                    $display("3. reverse  : %p", d);
    $display("4. original is untouched in the copy : %p", copy);

    names.sort();                   $display("5. strings sorted  : %p", names);
    names.rsort();                  $display("6. strings rsorted : %p", names);

    pkts.sort with (item.len);
    $write("7. packets by len        :");
    foreach (pkts[i]) $write(" id%0d(len %0d)", pkts[i].id, pkts[i].len);
    $display("");

    pkts.rsort(p) with (p.id);
    $write("8. packets by id, reverse:");
    foreach (pkts[i]) $write(" id%0d", pkts[i].id);
    $display("");

    d.sort with (-item);            $display("9. sort with (-item) : %p", d);

    d.shuffle();
    $display("10. after shuffle: size %0d, sum %0d", d.size(), d.sum());
  end

endmodule
