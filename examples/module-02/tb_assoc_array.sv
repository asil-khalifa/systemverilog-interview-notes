module tb_assoc_array;

  int    score [string];
  int    level [int];
  string name;
  int    key;

  initial begin
    score["ravi"] = 82;
    score["anu"]  = 95;
    score["zoya"] = 71;
    score["maya"] = 88;
    $display("1. entries = %0d", score.num());

    if (score.exists("anu"))  $display("2. anu is present, score %0d", score["anu"]);
    if (!score.exists("tom")) $display("3. tom is not present");

    if (score.first(name))
      do $display("4.   %s = %0d", name, score[name]);
      while (score.next(name));

    void'(score.last(name));  $display("5. last key          = %s", name);
    void'(score.prev(name));  $display("6. key before zoya   = %s", name);

    score.delete("ravi");
    $display("7. after delete(\"ravi\") entries = %0d", score.num());

    foreach (score[k]) $display("8.   %s = %0d", k, score[k]);

    score["maya"]++;                       // existing entry
    score["neel"]++;                       // new entry: created as 0, then incremented
    $display("9. maya = %0d  neel = %0d  entries = %0d",
             score["maya"], score["neel"], score.num());

    // integer keys: stored in numeric order, negative first for a signed index
    level[5]   = 50;
    level[-3]  = 30;
    level[100] = 10;
    void'(level.first(key));  $display("10. first key = %0d", key);
    void'(level.next(key));   $display("11. next key  = %0d", key);
    void'(level.last(key));   $display("12. last key  = %0d", key);
    if (!level.next(key))     $display("13. no key after %0d", key);

    $display("14. level[7] = %0d, entries still %0d", level[7], level.num());

    score.delete();
    $display("15. after delete() entries = %0d", score.num());
  end

endmodule
