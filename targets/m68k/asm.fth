\ Copyright 2016 Lars Brinkhoff

\ Assembler for Motorola 68000 and ColdFire.

\ Adds to FORTH vocabulary: ASSEMBLER CODE ;CODE.
\ Creates ASSEMBLER vocabulary with: END-CODE and 68000 opcodes.

\ This will become a cross assembler if loaded with a cross-compiling
\ vocabulary at the top of the search order.

\ Conventional prefix syntax: "<source> <destination> <opcode>,".
\ Addressing modes:
\ - immediate: "n #"
\ - absolute: n
\ - register: <reg>
\ - indirect: "<reg> )"
\ - posticrement: "<reg> )+"
\ - predecrement: "<reg> -)"
\ - indirect with displacement: "n <reg> )#"
\ - indexed: not supported yet
\ - pc relative: not supported yet

require search.fth
also forth definitions
require lib/common.fth

vocabulary assembler

base @  hex

\ This constant signals that an operand is not a direct address.
deadbeef constant -addr

\ Assembler state.
variable opcode
variable d
variable r2
variable dir?
variable size
variable disp   defer ?disp,
variable imm    defer ?imm,
defer imm,
defer reg
defer ?ea!

\ Set opcode.  And destination: register or memory.
: opcode!   3@ drop >r opcode ! ;
: !mem   dir? @ if 100 d ! then dir? off ;
: !reg   dir? off ;

: reg@   opcode 0E00 @bits ;
: reg!   opcode 0E00 !bits ;
: ea@   opcode 003F @bits ;
: >reg   ea@ 9 lshift reg! ;
: ea!   r2 @ if >reg then  opcode 003F !bits ;
: !size   size @ opcode +! ;

\ Access instruction fields.
: opmode   d @ ;
: opcode@   opcode @ ;
: imm@   imm @ ;
: disp@   disp @ ;

\ Possibly use a cross-compiling vocabulary to access a target image.
previous definitions

\ Write instruction fields to memory.
: h,   dup 8 rshift c, c, ;
: h!   over 8 rshift over c!  1+ c! ;
: w,   dup 10 rshift h, h, ;
: opcode,   opcode@ opmode + h, ;
: imm16,   imm@ h, ;
: imm32,   imm@ w, ;
: disp16,   disp@ h, ;
: disp32,   disp@ w, ;
: -pc   here negate ;

also forth definitions

\ Set immediate operand.
: -imm   ['] noop is ?imm, ;
: !imm16   ['] imm16, is imm, ;
: !imm32   ['] imm32, is imm, ;
: imm!   imm !  ['] imm, is ?imm, ;

\ Set operand size.
: .b   0000 size !  !imm16 ;
: .w   0040 size !  !imm16 ;
: .l   0080 size !  !imm32 ;

\ Set displacement.
: disp!   is ?disp, disp ! ;
: !disp16   ['] disp16, disp! ;
: !disp32   ['] disp32, disp! ;
: pc-relative   -pc + 2 - !disp16 ;
: relative    0 ea!  disp@ pc-relative ;

\ Implements addressing modes: register, indirect, postincrement,
\ predecrement, and absolute.
: reg3   9 lshift reg! ;
: reg2   ea! ;
: !reg2   ['] reg2 is reg ;
: !reg3   ['] reg3 is reg ;
: reg1   ea! !reg !reg2 ;
: ind   0018 xor ea! !mem !reg3 ;
: ind+   0008 xor ind ;
: ind-   0030 + ind ;
: ind#   swap !disp16  0038 xor ind ;
: pc-rel   pc-relative  0022 ind ;
: addr   !disp32  0039 ea! ;

\ Reset assembler state.
: 0reg   ['] reg1 is reg  r2 off ;
: 0disp   ['] noop is ?disp, ;
: 0imm   imm off  -imm  0 is imm, ;
: 0size   0 size ! ;
: 0opmode   d off 0size ;
: 0ea   ['] drop is ?ea! ;
: 0asm   0imm 0disp 0reg 0opmode 0ea  dir? on ;

\ Implements addressing mode: immediate.
: imm-op   imm!  003C ?ea! ;

\ Process one operand.  All operands except a direct address
\ have the stack picture ( n*x xt -addr ).
: addr?   dup -addr <> ;
: op   addr? if addr else drop execute then ;

\ Process the count operand to a shift instruction .
: reg?   dup ['] reg = ;
: reg-or-immediate   reg? if 2drop else execute then ;
: shift-op   addr? abort" Syntax error" drop  reg-or-immediate ;

\ Define instruction formats.
: instruction, ( a -- ) opcode! !size opcode, ?imm, ?disp, 0asm ;
: mnemonic ( u a "name" -- ) create ['] noop 3,  does> instruction, ;
: format:   create ] !csp  does> mnemonic ;
: immediate:   ' latestxt >body ! ;

\ The MOVE instruction fields are different.
: >dest   ea@ 9 lshift reg!  ea@ 3 lshift opcode 001C0 !bits  0reg ;
: >size   size @ 6 rshift 3 * 3 and dup 0= - 0C lshift size ! ;
\ ADDQ, SUBQ, MOVEQ, and shift instructions immediate field.
: imm?   action-of ?imm, ['] noop <> ;
: imm>   -imm imm @ swap lshift opcode rot !bits ;
: ?imm>   imm? if imm> else 2drop 0020 opcode +! then ;
\ ADDA, SUBA, and CMPA size field.
: a>size   size @ 1 lshift 0100 and size ! ;
\ EXT, and EXTB, size field.
: ext>size   size @ 1 rshift 0040 and size ! ;
\ Register operand.
: reg-op ( op mask -- ) >r opcode @ >r op r> opcode r> !bits ;

\ Instruction formats.
format: 0op ;
format: 1op   op d off ;
format: 1reg   FFF0 reg-op  d off ext>size ;
format: 2op   r2 on op op ;
format: 2opa   r2 on op op d off a>size ;
format: 2opi   op op d off ;
format: 2op-d   r2 on op op d off ;
format: 2op-move   op >dest  ['] ea! is ?ea!  op d off >size ;
format: addq/subq   op op d off  0E00 9 imm> ;
format: moveq   op >reg op d off  00FF 0 imm> ;
format: branch   op relative ;
format: imm   2drop opcode +! ;
format: shift   FFF8 reg-op  d off  !reg3 op 0E00 9 ?imm> ;

\ Define registers.
: reg:   create dup 000F and , 1+  does> @ ['] reg -addr ;

\ Instruction mnemonics.
previous also assembler definitions

0000 2op-move move,
0000 2op-move movea,
0000 2opi ori,
0200 2opi andi,
0400 2opi subi,
0600 2opi addi,
06C0 1reg rtm,
\ 0800 btst,
\ 0840 bchg,
\ 0880 bclr,
\ 08C0 bset,
0A00 2opi eori,
0C00 2opi cmpi,
0100 2op btst,
0140 2op bchg,
0180 2op bclr,
01C0 2op bset,
4000 1op negx,
41C0 2op-d lea,
4200 1op clr,
4400 1op neg,
4600 1op not,
4880 1reg ext,
4980 1reg extb,
\ 4808 link,
4840 1op pea,
4840 1op swap,
4848 imm bkpt,
\ 4880 movem,
4A00 1op tst,
4A7C 0op illegal,
4AC0 1op tas,
4E58 1reg unlk,
4E70 0op reset,
4E71 0op nop,
\ 4E72 stop,
4E73 0op rte,
4E75 0op rts,
4E76 0op trapv,
4E77 0op rtr,
4E80 1op jsr,
4E40 imm trap,
4EC0 1op jmp,
5000 addq/subq addq,
5100 addq/subq subq,
\ 50C0 scc
\ 50C8 dbcc
6000 branch bra,
6100 branch bsr,
6200 branch bhi,
6300 branch bls,
6400 branch bcc,
6500 branch bcs,
6600 branch bne,
6700 branch beq,
6800 branch bvc,
6900 branch bvs,
6A00 branch bpl,
6B00 branch bmi,
6C00 branch bge,
6D00 branch blt,
6E00 branch bgt,
6F00 branch ble,
7000 moveq moveq,
8000 2op or,
80C0 2op divu,
81C0 2op divs,
9000 2op sub,
90C0 2opa suba,
B000 2op cmp,
B0C0 2opa cmpa,
B000 2op eor,
\ B108 cmpm,
C000 2op and,
C0C0 2op mulu,
\ C100 exg,
C1C0 2op muls,
D000 2op add,
D0C0 2opa adda,
E000 shift asr,
E008 shift lsr,
E010 shift roxr,
E018 shift ror,
E100 shift asl,
E108 shift lsl,
E110 shift roxl,
E118 shift rol,

\ Addressing mode syntax: immediate, indirect, and displaced indirect.
: #   ['] imm-op -addr ;
: )   2drop ['] ind -addr  0reg ;
: )+   2drop ['] ind+ -addr  0reg ;
: -)   2drop ['] ind- -addr  0reg ;
: )#   2drop ['] ind# -addr  0reg ;
: pc)   ['] pc-rel -addr  0reg ;

\ Register names.
0
reg: d0  reg: d1  reg: d2  reg: d3  reg: d4  reg: d5  reg: d6  reg: d7
reg: a0  reg: a1  reg: a2  reg: a3  reg: a4  reg: a5  reg: a6  reg: a7
drop

\ Resolve jumps.
: >mark   here 2 - ['] h! here 2 - ;
: >resolve   here - negate -rot execute ;

\ Unconditional jumps.
: label   here >r get-current ['] assembler set-current r> constant set-current ;
: begin,   here ;
: again,   bra, ;
: ahead,   0 bra, >mark ;
: then,   >resolve ;

\ Conditional jumps.
: 0=,   ['] bne, ;
: 0<,   ['] bge, ;
: 0<>,   ['] beq, ;
: if,   0 swap execute >mark ;
: until,   execute ;

\ else,   ahead, 3swap then, ;
: while,   >r if, r> ;
: repeat,   again, then, ;

\ Runtime for ;CODE.  CODE! is defined elsewhere.
: (;code)   r> code! ;

\ Enter and exit assembler mode.
: start-code   also assembler 0asm ;
: end-code     align previous ;

also forth base ! previous

previous definitions also assembler

\ Standard assembler entry points.
: code    parse-name header, ?code, reveal start-code  ;
: ;code   postpone (;code) reveal postpone [ ?csp start-code ; immediate

0asm
previous
