  processor 6502
  org $1000

  jmp main

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

setup SUBROUTINE setup:
  jsr $e544 ; clear screen
  lda #11 ; border color
  sta $d020
  lda #2 ; bg color
  sta $d021
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

draw_border SUBROUTINE draw_border:
  ; draw play field border
  ; uses $80 and $81 for pointers
  ldx #0 ; index
.first_and_last_line_loop:
  lda #35 ; char code for the border
  sta $400,x ; poke to screen memory
  sta $7c0,x ; poke to screen memory
  lda #00 ; color for the char
  sta $d800,x ; poke to color ram
  sta $dbc0,x ; poke to color ram
  inx
  cpx #40
  bne .first_and_last_line_loop
  ldx 1 ; index

  ; draw sides
  lda #$04
  sta $81 ; address
  lda #40
  sta $80
.sides_loop:
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

  lda #0 ; color code
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
  jmp .sides_loop
draw_sides_out:
  lda $80
  cmp #$c0
  bne .sides_loop

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

game_setup SUBROUTINE game_setup:
  jsr draw_border

  ; position of head: (82,83) (both as ptr to screen memory)
  ; position of tail: (84,85)
  lda #$5
  sta $83
  lda #$f4
  sta $82
  lda #$6
  sta $84
  lda #$58
  sta $85

  ; snek direction 86
  lda #$0 ; 0 - north; 1 - east; 2 - south; 3 - west
  sta $86

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

game_loop SUBROUTINE game_loop:
  ; Idea here: this provides all the game play, and loops until game over. then the main routine
  ; takes care of displaying game over screen / welcome screen and re-starting if the player chooses
  ; to.

  ; TODO fill color ram with snake color - before drawing border
  ;      when drawing goodies, they should be a different color - maybe it makes sense to have a
  ;      subroutine for drawing them. when eating them, the color ram has to be reset to snek color.

  ; TODO draw segment according to direction where head was in last round

  ; move head
  lda $86
  cmp #0
  beq .move_north
  cmp #1
  beq .move_east
  cmp #2
  beq .move_south

  ; move west -- TODO lots of duplicate code -- make macro
  sec
  lda $82
  sbc #1
  sta $82
  lda $83
  sbc #0
  sta $83
  jmp .move_out

.move_north:
  sec
  lda $82
  sbc #40
  sta $82
  lda $83
  sbc #0
  sta $83
  jmp .move_out

.move_east:
  clc
  lda $82
  adc #1
  sta $82
  lda $83
  adc #0
  sta $83
  jmp .move_out

.move_south:
  clc
  lda $82
  adc #40
  sta $82
  lda $83
  adc #0
  sta $83
  jmp .move_out

.move_out:

  ; check collision
  ldy #0
  lda ($82),y
  cmp #32 ; space
  beq .continue
  rts ; game over. -- TODO once we have a "life counter", subtract a life and restart

.continue:

  ; draw new segment where head is
  lda #81
  ldy #0
  sta ($82),y


  ; TODO check segment where tail is, delete it and advance tail

  jmp game_loop

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

main SUBROUTINE main:
  jsr setup
  jsr game_setup
  jsr game_loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

end_loop:
  jmp end_loop
