  processor 6502
  org $1000

  lda #$00 ; bläck
  sta $d020
  sta $d021

  tax
  lda #$20 ; späce

  ; screen clear loop.
  ; screen is from $0400 to $07ff
  ; loops backwards from 255 to 0, then breaks
loop:
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  dex
  bne loop

wait:
  jmp wait
