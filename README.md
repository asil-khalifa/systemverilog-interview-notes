# SystemVerilog Interview Preparation Notes

Detailed study notes for SystemVerilog interviews for VLSI Design Verification roles. Each concept is explained from the basics: what it is, why it exists, how it behaves in a simulator, complete code with a line-by-line explanation, comparison tables, common mistakes, and interview questions with answers.

## Download

| Module | Topic | PDF |
|---|---|---|
| 1 | SystemVerilog Fundamentals and Data Types | [SystemVerilog_Module_01_Fundamentals_and_Data_Types.pdf](pdf/SystemVerilog_Module_01_Fundamentals_and_Data_Types.pdf) |
| 2 | Arrays and Array Operations | [SystemVerilog_Module_02_Arrays_and_Array_Operations.pdf](pdf/SystemVerilog_Module_02_Arrays_and_Array_Operations.pdf) |
| 3 | Tasks, Functions and Procedural Concepts | [SystemVerilog_Module_03_Tasks_Functions_Procedural.pdf](pdf/SystemVerilog_Module_03_Tasks_Functions_Procedural.pdf) |
| 4 | Classes and Object-Oriented Programming | [SystemVerilog_Module_04_Classes_and_OOP.pdf](pdf/SystemVerilog_Module_04_Classes_and_OOP.pdf) |
| 5 | Randomization and Constraints | [SystemVerilog_Module_05_Randomization_and_Constraints.pdf](pdf/SystemVerilog_Module_05_Randomization_and_Constraints.pdf) |
| 6 | Transaction Classes and Verification Planning | [SystemVerilog_Module_06_Transactions_and_Verification_Planning.pdf](pdf/SystemVerilog_Module_06_Transactions_and_Verification_Planning.pdf) |
| 7 | Inter-Process Communication and Synchronization | [SystemVerilog_Module_07_IPC_and_Synchronization.pdf](pdf/SystemVerilog_Module_07_IPC_and_Synchronization.pdf) |
| 8 | Interfaces and Modports | [SystemVerilog_Module_08_Interfaces_and_Modports.pdf](pdf/SystemVerilog_Module_08_Interfaces_and_Modports.pdf) |
| 9 | Layered Testbench Architecture | [SystemVerilog_Module_09_Layered_Testbench.pdf](pdf/SystemVerilog_Module_09_Layered_Testbench.pdf) |
| 10 | Functional Coverage and Assertions | [SystemVerilog_Module_10_Coverage_and_Assertions.pdf](pdf/SystemVerilog_Module_10_Coverage_and_Assertions.pdf) |
| 11 | Packages, Advanced Concepts and UVM Introduction | [SystemVerilog_Module_11_Packages_Advanced_UVM_Intro.pdf](pdf/SystemVerilog_Module_11_Packages_Advanced_UVM_Intro.pdf) |
| | Final interview preparation (326 questions, 10 coding exercises) | [SystemVerilog_Module_12_Final_Interview_Preparation.pdf](pdf/SystemVerilog_Module_12_Final_Interview_Preparation.pdf) |

To download a PDF, open it on GitHub and use the download button at the top right of the viewer.

## Repository layout

| Path | Contents |
|---|---|
| `pdf/` | The finished PDFs, one per module |
| `notes/module-NN/` | Markdown source of the notes |
| `examples/module-NN/` | Every named code example from the notes as a separate `.sv` file |
| `build.py` | Script that turns the Markdown into the PDF and extracts the examples |

## Running the code examples

The examples are standard IEEE 1800 SystemVerilog. The easiest way to run them is [EDA Playground](https://www.edaplayground.com), which gives browser access to commercial simulators: paste the file into the testbench pane, choose a SystemVerilog simulator and run.

Most `tb_*.sv` and `ex*.sv` files are self-contained. Examples that use the ALU need `alu_pkg.sv` and `alu.sv` (in `examples/module-01/`) compiled first, in that order; the text of each module says which examples these are. The complete layered testbench is in `examples/module-09/`; compile `alu_pkg.sv`, `alu_if.sv`, `alu.sv`, `alu_tb_pkg.sv`, `tb_top.sv` in that order (the class files are included by the package and are not compiled directly). The UVM skeleton in `examples/module-11/` needs a UVM library.

**None of the code in this repository has been compiled or simulated.** The expected outputs printed in the notes were derived by hand from the IEEE 1800 rules. Run the examples yourself, and treat a compile error or a different output as something to investigate and report. Outputs of randomized examples are labelled as samples. The layout printed by `%p`, the order of threads that run in the same time step, and the wording of tool-generated messages vary between simulators.

## Rebuilding the PDFs

```
python3 -m venv venv
venv/bin/pip install -r requirements.txt
venv/bin/python build.py        # all modules
venv/bin/python build.py 01     # one module
```

WeasyPrint needs the Pango library, which is present on most Linux desktops. The fonts used are Liberation Sans and DejaVu Sans Mono.
