  processor 6502

  ; constants
border_color set 11 ; screen border
bg_color set 13 ; background
barrier_color set 0 ; game board border
barrier_char_code set 35 ; char code for the border 35 = #
snek_head set 81 ; char code for the snake head 81 = dot in the middle
snek_horz set 67 ; line drawing chars for snek body
snek_vert set 66
snek_dl set 73
snek_ul set 75
snek_dr set 85
snek_ur set 74

; autostart
  org $0801
  .byte $0c,$08,$0a,$00,$9e,$20,$34,$30,$39,$36,$00,$00,$00

; pointers (stuff I want in zero page)
head_h equ $fe
head_l equ $fd
tail_h equ $fc
tail_l equ $fb

; variables
  org $0900
frame_ctr: .byte $00
direction: .byte $00
prev_dir: .byte $00

; program
  org $1000

main SUBROUTINE
  jsr setup

.loop_forever:
  jsr game_setup
  jsr game_loop
  jmp .loop_forever

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

setup SUBROUTINE setup:
  jsr $e544 ; clear screen
  lda #border_color
  sta $d020
  lda #bg_color
  sta $d021
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

draw_border SUBROUTINE draw_border:
  ; draw play field border
  ; uses $fb and $fc for pointer
  ldx #0 ; index
.first_and_last_line_loop:
  lda #barrier_char_code ; char code for the border
  sta $400,x ; poke to screen memory
  sta $7c0,x ; poke to screen memory
  lda #barrier_color ; color for the char
  sta $d800,x ; poke to color ram
  sta $dbc0,x ; poke to color ram
  inx
  cpx #40
  bne .first_and_last_line_loop
  ldx 1 ; index

  ; draw sides
  lda #$04
  sta $fc ; address
  lda #40
  sta $fb
.sides_loop:
  lda #35 ; character code for the border
  ldy #$0
  sta ($fb),y
  ldy #39
  sta ($fb),y

  ; now, add d4 to the high byte to get to the color ram
  clc
  lda #$d4
  adc $fc
  sta $fc

  lda #0 ; color code
  sta ($fb),y ; assumes y to still be 39
  ldy #$0
  sta ($fb),y

  sec ; subtract d4 again to get back into screen ram
  lda $fc
  sbc #$d4
  sta $fc

  lda #40 ; add 40 to the value in (fc,fb)
  clc
  adc $fb
  sta $fb
  lda #0
  adc $fc
  sta $fc

  lda $fc
  cmp #$07
  beq draw_sides_out ; just do the last few lines
  jmp .sides_loop
draw_sides_out:
  lda $fb
  cmp #$c0
  bne .sides_loop

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

game_setup SUBROUTINE game_setup:
  jsr draw_border

  ; TODO clean inside of play area - and set a nice color for the snake

  lda #$5 ; initialize head and tail
  sta head_h
  lda #$f4
  sta head_l
  lda #$6
  sta tail_l
  lda #$58
  sta tail_h

  ; snek direction
  lda #$0 ; 0 - north; 1 - east; 2 - south; 3 - west
  sta direction
  sta prev_dir

  ; setup interrupt handler
  sei ; disable interrupt

  lda #$7f ; disable cia I, II, and VIC interrupts
  sta $dc0d
  sta $dd0d

  lda #$01 ; enable raster interrupt
  sta $d01a

  lda #$1b ; single color text mode
  ldx #$08
  ldy #$14
  sta $d011
  stx $d016
  sty $d018

  lda #<irq ; install our interrupt handler
  ldx #>irq
  sta $0314
  stx $0315

  ldy #$42 ; raster interrupt at some line
  sty $d012

  lda $dc02 ; clear pending interrupts
  lda $dd0d
  asl $d019

  cli ; enable interrupt

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

irq: ; inerrupt handler
  inc frame_ctr
  jsr read_input
  asl $d019 ; ack interrupt
  jmp $ea81 ; restore stack

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_input SUBROUTINE read_input:
  ; reads the joystick and adjusts the snek direction accordingly
  lda $dc01 ; joystick port 1
  tax

  ; TODO ignore "backwards"
  and #$1
  cmp #$1
  bne .up

  txa
  and #$2
  cmp #$2
  bne .down

  txa
  and #$4
  cmp #$4
  bne .left

  txa
  and #$8
  cmp #$8
  bne .right

  rts ; fall through means no direction pressed, so no change in direction

.up:
  lda #0
  sta direction
  rts
.down:
  lda #2
  sta direction
  rts
.left:
  lda #3
  sta direction
  rts
.right:
  lda #1
  sta direction
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

game_loop SUBROUTINE game_loop:
  ; Idea here: this provides all the game play, and loops until game over. then the main routine
  ; takes care of displaying game over screen / welcome screen and re-starting if the player chooses
  ; to.

  ; TODO when drawing goodies, they should be a different color - maybe it makes sense to have a
  ;      subroutine for drawing them. when eating them, the color ram has to be reset to snek color.

  ; replace head by line segment =======
  ; (this could be moved into the "move head" blocks probably, and save some branches, but this is
  ; an optimization that would make the code harder to read, so we don't do it until we run into
  ; problems)
  ; (we assume direction does not change while this routine is running, i.e. that is completes
  ; fast enough before the next raster interrupt fires)
  lda direction
  cmp #0
  beq .moving_north
  cmp #1
  beq .moving_east
  cmp #2
  beq .moving_south

  ; moving west
  lda prev_dir
  cmp #0
  beq .downleft ; #1: don't care (would be reversing directions)
  cmp #2
  beq .upleft
  jmp .horz ; fallthrough #3

.moving_north:
  lda prev_dir
  cmp #0
  beq .vert
  cmp #1
  beq .upleft ; #2 don't care
  jmp .upright ; fallthrough #3

.moving_east:
  lda prev_dir
  cmp #0
  beq .downright
  cmp #1
  beq .horz ; fallthrough #2
  jmp .upright ; #3 don't care

.moving_south:
  lda prev_dir ; #0 don't care
  cmp #1
  beq .downleft
  cmp #2
  beq .vert
  jmp .downright ; fallthrough #3

  ; replace head character by appropriate body character
.horz:
  lda #snek_horz
  jmp .replacehead
.vert:
  lda #snek_vert
  jmp .replacehead
.downleft:
  lda #snek_dl
  jmp .replacehead
.upleft:
  lda #snek_ul
  jmp .replacehead
.downright:
  lda #snek_dr
  jmp .replacehead
.upright:
  lda #snek_ur

.replacehead:
  ldy #0
  sta (head_l),y


  ; move head =========================
  lda direction
  sta prev_dir ; store previous direction for next round
  cmp #0
  beq .move_north
  cmp #1
  beq .move_east
  cmp #2
  beq .move_south

  ; move west -- TODO lots of duplicate code -- make macro
  sec
  lda head_l
  sbc #1
  sta head_l
  lda head_h
  sbc #0
  sta head_h
  jmp .move_out

.move_north:
  sec
  lda head_l
  sbc #40
  sta head_l
  lda head_h
  sbc #0
  sta head_h
  jmp .move_out

.move_east:
  clc
  lda head_l
  adc #1
  sta head_l
  lda head_h
  adc #0
  sta head_h
  jmp .move_out

.move_south:
  clc
  lda head_l
  adc #40
  sta head_l
  lda head_h
  adc #0
  sta head_h
  jmp .move_out

.move_out:

  ; check collision
  ldy #0
  lda (head_l),y
  cmp #32 ; space
  beq .continue
  rts ; game over. -- TODO once we have a "life counter", subtract a life and restart

.continue:

  ; draw new segment where head is
  lda #snek_head
  ldy #0
  sta (head_l),y


  ; TODO check segment where tail is, delete it and advance tail

.timer_loop
  lda frame_ctr
  cmp #30
  bne .timer_loop
  lda #0
  sta frame_ctr

  jmp game_loop

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
