module tb_access;

  class account;
    local     int balance;                 // hidden
    protected int limit = 1000;            // visible to subclasses
    string    owner;                       // public

    function new(string owner, int balance);
      this.owner   = owner;
      this.balance = balance;
    endfunction

    function void deposit(int amount);
      if (amount > 0) balance += amount;   // the class guards its own data
    endfunction

    function bit withdraw(int amount);
      if (amount <= 0 || amount > balance) return 0;
      balance -= amount;
      return 1;
    endfunction

    function int get_balance();
      return balance;
    endfunction

    function bit richer_than(account other);
      return balance > other.balance;      // local member of ANOTHER account object: legal
    endfunction
  endclass

  class premium_account extends account;
    function new(string owner, int balance);
      super.new(owner, balance);
      limit = 5000;                        // protected member of the base class: legal
      // balance = 0;                      // ILLEGAL: balance is local to account
    endfunction

    function void show();
      $display("%s: limit=%0d balance=%0d", owner, limit, get_balance());
    endfunction
  endclass

  account         a;
  premium_account b;
  bit             ok;

  initial begin
    a = new("asha", 100);
    a.deposit(50);
    $display("1. balance=%0d", a.get_balance());
    ok = a.withdraw(500);
    $display("2. withdraw 500 ok? %0d   balance=%0d", ok, a.get_balance());
    ok = a.withdraw(100);
    $display("3. withdraw 100 ok? %0d   balance=%0d", ok, a.get_balance());

    b = new("ben", 900);
    b.show();
    $display("4. ben richer than asha? %0d", b.richer_than(a));

    a.owner = "asha k";                    // public: legal
    // a.balance = 1_000_000;              // ILLEGAL: local
    // a.limit   = 0;                      // ILLEGAL: protected
  end

endmodule
