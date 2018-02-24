  processor 6502
  org $1000

  jmp main

setup:
  jsr $e544 ; clear screen
  lda #11 ; border color
  sta $d020
  lda #2 ; bg color
  sta $d021
  rts

draw_play_field_border:
  ; draw play field border
  ; uses $80 and $81 for pointers
  ldx #0 ; index
draw_first_and_last_line_loop:
  lda #35 ; char code for the border
  sta $400,x ; poke to screen memory
  sta $7c0,x ; poke to screen memory
  lda #00 ; color for the char
  sta $d800,x ; poke to color ram
  sta $dbc0,x ; poke to color ram
  inx
  cpx #40
  bne draw_first_and_last_line_loop
  ldx 1 ; index

  ; draw sides
  lda #$04
  sta $81 ; address
  lda #40
  sta $80
draw_sides_loop:
  lda #35 ; character code for the border
  ldy #$0
  sta ($80),y
  ldy #39
  sta ($80),y

  ; now, add d4 to the high byte to get to the color ram
  clc
  lda #$d4
  adc $81
  sta $81

  lda #00 ; color code
  sta ($80),y ; assumes y to still be 39
  ldy #$0
  sta ($80),y

  sec ; subtract d4 again to get back into screen ram
  lda $81
  sbc #$d4
  sta $81

  lda #40 ; add 40 to the value in (81,80)
  clc
  adc $80
  sta $80
  lda #0
  adc $81
  sta $81

  lda $81
  cmp #$07
  beq draw_sides_out ; just do the last few lines
  jmp draw_sides_loop
draw_sides_out:
  lda $80
  cmp #$c0
  bne draw_sides_loop

  rts


main:
  jsr setup
  jsr draw_play_field_border

endloop:
  jmp endloop
