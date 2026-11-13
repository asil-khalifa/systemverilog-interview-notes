# Final Interview Preparation: How to Use This Section

This section is the question bank for the whole course. It contains more than 300 numbered questions with answers, grouped by the kind of question an interviewer asks, not by module. Use it after you have studied Modules 1 to 11.

**Cross-references.** "M5" means Module 5. The modules are: M1 data types, M2 arrays, M3 tasks and functions, M4 classes and OOP, M5 randomization and constraints, M6 transactions and verification planning, M7 inter-process communication, M8 interfaces, M9 layered testbench, M10 coverage and assertions, M11 packages, advanced topics and UVM.

**Naming.** The examples use the course names: the DUT `alu` with the opcode type `alu_op_e`, the interface `alu_if` with clocking blocks `drv_cb` and `mon_cb`, the transaction `alu_txn`, the components `alu_generator`, `alu_driver`, `alu_monitor`, `alu_scoreboard`, `alu_env`, `alu_test`, the mailboxes `gen2drv_mbx` and `mon2scb_mbx`, and the FIFO `sync_fifo`.

> **Note:** No simulator was available when these notes were written. Every predicted output was derived by hand from the IEEE 1800-2017 rules. Output-prediction questions were chosen so that the result is fully determined by the language (no dependence on random seeds or on the order in which a simulator runs threads that wake at the same time). Run the code yourself; if your simulator prints something different, find out why.

## How the Section Is Organised

| Part | Questions | Content |
|---|---|---|
| Basic questions | Q1 to Q55 | One- or two-sentence answers; the first ten minutes of an interview |
| Intermediate questions | Q56 to Q110 | "Explain the difference", "what happens if" |
| Advanced questions | Q111 to Q146 | Scheduling regions, solver behaviour, polymorphism details, sampling |
| Output prediction | Q147 to Q170 | Short programs; you state the exact output |
| Code debugging | Q171 to Q186 | Code that compiles but misbehaves |
| Find the error | Q187 to Q202 | Code that does not compile |
| Write the code | Q203 to Q219 | Small programs written on a whiteboard or shared editor |
| Constraint writing | Q220 to Q243 | The most common coding questions in DV interviews |
| OOP questions | Q244 to Q259 | |
| IPC questions | Q260 to Q275 | |
| Layered testbench questions | Q276 to Q291 | |
| Industry scenarios | Q292 to Q308 | "The test hangs. What do you do?" |
| Fresher questions | Q309 to Q326 | Including "explain your project" |
| Coding exercises | 10 exercises | Larger programs with complete solutions |

## How to Answer a Technical Question

A good answer has a fixed shape. Practise it until it is automatic.

1. **Definition.** One sentence saying what the thing is, using the correct term.
2. **Why it exists.** One sentence about the problem it solves.
3. **Example.** A two- or three-line code fragment, or a concrete use in a testbench.
4. **Pitfall or comparison.** One thing people get wrong, or how it differs from the nearest related concept.

Example for "What is a virtual interface?":

> **How to say it in an interview:** "A virtual interface is a handle, a variable that refers to an actual interface instance. It is needed because classes are dynamic objects and cannot contain an interface instance or connect to module ports, so the class holds a handle and the testbench top assigns the real interface to it. For example the driver has `virtual alu_if vif;` and drives `vif.drv_cb.a <= txn.a;`. The common mistake is to use it before it is assigned, which gives a null-handle error at run time."

Rules that apply to every answer:

- Answer the question that was asked first, then add detail. Do not start with history.
- If you do not know, say what you do know and how you would find out. Guessing confidently is worse than "I have not used that; my understanding is ...".
- When writing code, say what you are doing while you write. State assumptions ("I assume the reset is active low").
- When asked to predict output, go line by line and say the state after each line. Interviewers give credit for the method even when the final answer is wrong.
- When asked to debug, do not guess the fix. Say how you would narrow it down: reproduce with the same seed, find the first wrong thing in the log or waveform, form a hypothesis, test it.

## The Most Frequently Asked Topics

If you have only one evening, make sure you can answer every line below without notes. The number in brackets is where the full answer is.

| Topic | Question | Where |
|---|---|---|
| Data types | `logic` vs `bit` vs `reg` vs `wire`; two-state vs four-state | M1, Q3 |
| Data types | `==` vs `===` vs `==?` | M1 |
| Arrays | Static vs dynamic vs associative vs queue: when to use each | Q57 |
| Arrays | Queue methods; array locator methods | Q9, Q61 |
| Procedural | Task vs function; `automatic` vs `static`; `ref` | Q13, Q15, Q65 |
| Procedural | Blocking vs nonblocking assignment | Q56 |
| OOP | Class vs object vs handle; shallow vs deep copy | Q18, Q69 |
| OOP | Inheritance, polymorphism, virtual methods, `$cast` | Q26, Q72, Q73 |
| OOP | Abstract class, pure virtual method | Q28 |
| Randomization | `rand` vs `randc`; `randomize()` return value | Q29, Q30 |
| Randomization | `inside`, `dist`, implication, `solve before`, `soft`, `unique` | Q78 to Q82 |
| Randomization | `constraint_mode()` vs `rand_mode()`; pre/post randomize | Q35, Q36 |
| Randomization | Writing constraints for arrays | Q220 to Q243 |
| IPC | `fork`...`join` vs `join_any` vs `join_none`; `disable fork`; `wait fork` | Q44, Q89 |
| IPC | Mailbox vs semaphore vs event; `@e` vs `wait(e.triggered)` | Q87, Q88 |
| Interfaces | Interface, modport, clocking block, virtual interface | Q45 to Q48 |
| Testbench | Role of generator, driver, monitor, scoreboard, environment, test | Q49 |
| Testbench | How data flows and how the test ends | Q276, Q282 |
| Coverage | Code vs functional coverage; bins; cross; ignore vs illegal bins | Q39, Q99 |
| Assertions | Immediate vs concurrent; `\|->` vs `\|=>`; `disable iff`; `$past` | Q50, Q51 |
| Scheduling | Event regions; why clocking blocks remove races | Q111, Q113 |
| UVM | What it is and how it maps to plain SystemVerilog | Q55, Q110 |
