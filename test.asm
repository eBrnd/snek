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
clear_loop:
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  dex
  bne clear_loop

  ; rasterlines
loop:
  lda $d012 ; raster line low byte
  sec
  sbc #$10
  bpl upper

  ; lower
  lda #$04
  sta $d021
  jmp loop

upper:
  lda #$05
  sta $d021
  jmp loop
