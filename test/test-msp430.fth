require search.fth

include lib/intel-hex.fth

vocabulary cross
only forth also cross definitions
0 constant t-little-endian
0 constant t-endian
include lib/image.fth
include targets/msp430/asm.fth

hex only forth definitions also cross

F800 constant load-address

also assembler
target-image
load-address org

  5A80 # 120 & mov,
  48 # 67 & .b mov,
  69 # 67 & .b mov,
  20 # 67 & .b mov,
  begin,
    66 & r10 .b mov,
    1# r10 add,
    r10 67 & .b mov,
  again,  

host-image
load-address target-region nip t-image swap type-hex bye
