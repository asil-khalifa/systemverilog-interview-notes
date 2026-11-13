#include <stdio.h>
#include "svdpi.h"

/* Exported from SystemVerilog: declared here so that C can call it. */
extern void sv_log(const char* msg);

/* A reference model of the ALU (opcode numbering as in alu_pkg). 9-bit result. */
int c_alu_model(int op, int a, int b)
{
    int r;
    a &= 0xFF;
    b &= 0xFF;
    switch (op) {
        case 0:  r = a + b;         break;   /* ALU_ADD */
        case 1:  r = a - b;         break;   /* ALU_SUB */
        case 2:  r = a & b;         break;   /* ALU_AND */
        case 3:  r = a | b;         break;   /* ALU_OR  */
        case 4:  r = a ^ b;         break;   /* ALU_XOR */
        case 5:  r = (~a) & 0xFF;   break;   /* ALU_NOT */
        case 6:  r = a << 1;        break;   /* ALU_SHL */
        default: r = a >> 1;        break;   /* ALU_SHR */
    }
    return r & 0x1FF;
}

/* Output arguments arrive as pointers. */
void c_minmax(int a, int b, int* lo, int* hi)
{
    *lo = (a < b) ? a : b;
    *hi = (a < b) ? b : a;
}

/* A context function: it calls back into SystemVerilog. */
void c_greet(const char* name)
{
    char buf[128];
    snprintf(buf, sizeof(buf), "hello from C, %s", name);
    sv_log(buf);
}
