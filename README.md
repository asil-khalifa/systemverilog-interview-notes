# SystemVerilog Interview Preparation Notes

Detailed study notes for SystemVerilog interviews for VLSI Design Verification roles. Each concept is explained from the basics: what it is, why it exists, how it behaves in a simulator, complete code with a line-by-line explanation, comparison tables, common mistakes, and interview questions with answers.

## Download

| Module | Topic | PDF |
|---|---|---|
| 1 | SystemVerilog Fundamentals and Data Types | [SystemVerilog_Module_01_Fundamentals_and_Data_Types.pdf](pdf/SystemVerilog_Module_01_Fundamentals_and_Data_Types.pdf) |
| 2 | Arrays and Array Operations | not written yet |
| 3 | Tasks, Functions and Procedural Concepts | not written yet |
| 4 | Classes and Object-Oriented Programming | not written yet |
| 5 | Randomization and Constraints | not written yet |
| 6 | Transaction Classes and Verification Planning | not written yet |
| 7 | Inter-Process Communication and Synchronization | not written yet |
| 8 | Interfaces and Modports | not written yet |
| 9 | Layered Testbench Architecture | not written yet |
| 10 | Functional Coverage and Assertions | not written yet |
| 11 | Packages, Advanced Concepts and UVM Introduction | not written yet |
| | Final interview preparation (150+ questions) | not written yet |

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

`tb_alu_directed.sv` needs `alu_pkg.sv` and `alu.sv` compiled before it, in that order. All other `tb_*.sv` files are self-contained.

**The expected outputs printed in the notes were derived by hand from the IEEE 1800 rules. They have not been checked against a simulator run.** Run the examples yourself, and treat any difference as something to investigate. The layout printed by `%p` is known to vary between simulators.

## Rebuilding the PDFs

```
python3 -m venv venv
venv/bin/pip install -r requirements.txt
venv/bin/python build.py        # all modules
venv/bin/python build.py 01     # one module
```

WeasyPrint needs the Pango library, which is present on most Linux desktops. The fonts used are Liberation Sans and DejaVu Sans Mono.
