  processor 6502

; constants ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
space_char set 32 ; free space on game board (= space character)
goodie_char set 83 ; char for the goodies (= heart)
score_vc set $20 ; voice control for scoring sound (without gate)
death_vc set $80 ; voice control for death sound (without gate)
inv_zero set 176 ; inverted "0" character for score and lives output
speed_slow set 10
speed_normal set 6
speed_fast set 4

; autostart ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  org $0801
  .byte $0c,$08,$0a,$00,$9e,$20,$34,$30,$39,$36,$00,$00,$00

; pointers (stuff I want in zero page) ;

head_h equ $fe
head_l equ $fd
tail_h equ $fc
tail_l equ $fb

; variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  org $0900
frame_ctr: .byte $00
direction: .byte $00
prev_dir: .byte $00 ; used for two things: determine what "corner" character to print, and prevent
                    ; snek from turning back into itself
tail_dir: .byte $00
legacy_mode: .byte $00
speed: .byte $00

; for goodie placer
rnd_row: .byte $00
rnd_col: .byte $00
spawn_retry_count: .byte $00
do_spawn_goodie: .byte $00

; score and live counter
score: .byte $00,$00
lives: .byte $00

; welcome screen - sprite location base
ws_sprite_base: .byte $00, $00

; macros ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  MAC show_sprite ; index; address
  lda #{2}/64
  sta $07f8+{1} ; set sprite ptr
  lda #187
  sta $d001+2*{1} ; y coord
  lda $1 ; color
  sta $d027+{1}
  ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  MAC move_sprite ; index // x and y contain the sprite base's low and high byte
  txa
  sta $d000+2*{1}
  tya
  cmp #2
  beq .over; it's on the right part of the screen -> set $d010 bit
  cmp #0
  beq .off; dropped off left side
  lda $d010
  and #$fe
  and #~[1<<{1}]
  sta $d010
  jmp .display
.over:
  lda $d010
  ora #[1<<{1}]
  sta $d010
  jmp .display
.off:
  lda $d015
  and #~[1<<{1}]
  sta $d015
  jmp .out
.display:
  lda $d015
  ora #[1<<{1}]
  sta $d015
.out:

  ; add 24 to the position (except when it's the last sprite)
  IF {1} < 7
  clc
  txa
  adc #24
  tax
  tya
  adc #0
  tay
  EIF

  ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  MAC print_string ; address, length, screen position
  ldy #0
.loop:
  lda #>{1}
  sta $64
  lda #<{1}
  sta $63
  lda ($63),y

  ldx #>{3}
  stx $64
  ldx #<{3}
  stx $63

  sta ($63),y

  iny
  tya
  cmp #{2}
  bne .loop
  ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  MAC clean_field ; first, last column, first, last row
  ; this has to be called before the snek position is initialized, because it clobbers the head
  ; pointer
  ldx #>($0400 + ({3} * 40))
  ldy #<($0400 + ({3} * 40))
  stx $fe
  sty $fd
  ldx #{3}

.row_loop:

  ldy #{1}
.col_loop:
  lda #space_char
  sta ($fd),y

  iny
  tya
  cmp #{2}
  bne .col_loop

  clc
  lda $fd
  adc #40
  sta $fd
  lda $fe
  adc #0
  sta $fe

  inx
  txa
  cmp #{4}
  bne .row_loop

.out:
  ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  MAC debounce_loop
  ldx #4 ; wait for raster line to appear twice
.debounce_loop:
.raster_loop:
  lda $d012
  cmp #$ff
  bne .raster_loop
  dex
  bne .debounce_loop
  ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

score_text .byte 147,131,143,146,133,160
lives_text .byte 140,137,150,133,147,160

  MAC draw_stats ; text, text length, score ptr, destination address, digits (2 or 4)
  print_string {1}, {2}, {4}

  lda {3}
  and #$0f
  clc
  adc #inv_zero
  sta {4}+{2}+{5}-2+1
  lda {3}
  lsr
  lsr
  lsr
  lsr
  and #$0f
  clc
  adc #inv_zero
  sta {4}+{2}+{5}-2+0
  IF {5} > 2
  lda {3}+1
  and #$0f
  clc
  adc #inv_zero
  sta {4}+{2}+1
  lda {3}+1
  lsr
  lsr
  lsr
  lsr
  clc
  adc #inv_zero
  sta {4}+{2}+0
  EIF

  ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  org $1000

main SUBROUTINE
  jsr setup

.loop_forever:
  jsr title_screen
  jsr welcome_screen
  jsr $e544 ; clear screen

  ; turn off all the sprites
  lda #$00
  sta $d015

  jsr game_setup
.loop_round:
  jsr round_setup
  jsr game_loop

  ; account for lives
  sed
  sec
  lda lives
  sbc #1
  sta lives
  cld
  bne .loop_round ; new round if >0 lives left

  jsr game_over
  jmp .loop_forever

  brk

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

title_screen SUBROUTINE title_screen:
  jsr draw_image

  show_sprite 0, sprite1
  show_sprite 1, sprite2
  show_sprite 2, sprite3
  show_sprite 3, sprite4
  show_sprite 4, sprite5
  show_sprite 5, sprite6
  show_sprite 6, sprite7
  show_sprite 7, sprite8

  ; install title screen interrupt handler
  sei ; disable interrupt

  lda #$7f ; disable cia I, II, and VIC interrupts
  sta $dc0d
  sta $dd0d

  lda #$01 ; enable raster interrupt
  sta $d01a

  lda #<ts_irq ; install our interrupt handler
  ldx #>ts_irq
  sta $0314
  stx $0315

  ldy #$42 ; raster interrupt at some line
  sty $d012

  lda $dc02 ; clear pending interrupts
  lda $dd0d
  asl $d019

  cli ; enable interrupt

  jsr wait_fire

  ; disable raster interrupt
  sei
  lda #$00
  sta $d01a
  cli

  ; reset graphics mode
  lda #$1b ; single color text mode
  ldx #$08
  ldy #$14
  sta $d011
  stx $d016
  sty $d018

  jsr $e544 ; clear screen
  lda #23
  sta 53272 ; lowercase mode

  rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

line1 .byte "SNEK"
line2 .byte "F1 - NORMAL MODE"
line3 .byte "F3 - LEGACY MODE"
line4 .byte "F5 - CHANGE SPEED"

welcome_screen SUBROUTINE welcome_screen:

  print_string line1, 4, $0400
  print_string line2, 16, $0428
  print_string line3, 16, $0450
  print_string line4, 17, $0478

  jsr print_speed

  ; wait for key press
  sei
  lda #%11111111
  sta $dc02 ; DDRA
  lda #%00000000
  sta $dc03 ; DDRB
  lda #%11111110 ; column 0
  sta $dc00 ; PRA
  cli
.key_loop:
  ldx $dc01 ; PRB
  txa
  and #%01000000 ; row 6 (F5)
  beq .change_speed
  txa
  and #%00100000 ; row 5 (F3)
  beq .legacy
  txa
  and #%00010000 ; row 4 (F1)
  beq .normal
  jmp .key_loop

.normal:
  lda #0
  sta legacy_mode
  rts

.legacy:
  lda #1
  sta legacy_mode
  rts

.change_speed:
  debounce_loop

.wait_key_release:
  lda $dc01 ; PRB
  and #%01000000 ; row 6 (F5)
  beq .wait_key_release

  jsr change_speed
  jsr print_speed

  debounce_loop

  jmp .key_loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

draw_image SUBROUTINE draw_image:
  lda #$0d
  sta $d020
  sta $d021

  ldx #$00
.img_loop:
  ; charmem
  lda $3d40,x
  sta $0400,x
  lda $3e40,x
  sta $0500,x
  lda $3f40,x
  sta $0600,x

  txa ; the lower part of the bitmap doesn't exist, so we would display garbage there. we just fill
  sec ; the charmem with the background color, so the garbage is invisible.
  sbc #$20
  bcc .load
  lda #$dd
  jmp .noload
.load:
  lda $4040,x
.noload:
  sta $0700,x

  ; colormem
  lda $4088,x
  sta $d800,x
  lda $4188,x
  sta $d900,x
  lda $4288,x
  sta $da00,x

  ; same as above - make the garbage invisible. since colormem is not used in the lower part of the
  lda #$dd ; bitmap anyway (it's just a thick bar only using a color from charmem), we don't have
  sta $db00,x ; to bother copying anything and can fill it with the background color

  inx
  bne .img_loop

  lda #$3b ; bitmap mode
  sta $d011
  lda #$18 ; multicolor mode
  sta $d016

  lda #$18 ; screen ram at 400, bitmap at 2000
  sta $d018

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

slow .byte   " SLOW "
medium .byte "MEDIUM"
fast .byte   " FAST "

print_speed SUBROUTINE print_speed:
  lda speed
  cmp #speed_slow
  beq .slow
  cmp #speed_normal
  beq .medium

  ; fast
  print_string fast, 6, $04a0
  rts

.slow:
  print_string slow, 6, $04a0
  rts

.medium:
  print_string medium, 6, $04a0
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

change_speed SUBROUTINE change_speed:
  lda speed
  cmp #speed_slow
  beq .set_normal
  cmp #speed_normal
  beq .set_fast

  ; set_slow
  lda #speed_slow
  sta speed
  rts

.set_normal:
  lda #speed_normal
  sta speed
  rts

.set_fast
  lda #speed_fast
  sta speed
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

game_over_msg_1 .byte "GAME OVER"
game_over_msg_2 .byte "FIRE TO RESTART"

game_over SUBROUTINE game_over:
  jsr $e544 ; clear screen
  lda #23
  sta 53272 ; lowercase mode

  print_string game_over_msg_1, 9, $0428
  print_string game_over_msg_2, 15, $0450

  draw_stats score_text, 6, score, $0478, 4

  jsr wait_fire

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

wait_fire SUBROUTINE wait_fire:

.loop_press:
  lda $dc01 ; joystick port 1
  and #$10
  bne .loop_press

  debounce_loop

  ; wait until button is released, so it doesn't misfire F1
.loop_release:
  lda $dc01
  and #$10
  beq .loop_release

  debounce_loop
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

setup SUBROUTINE setup:
  jsr $e544 ; clear screen
  lda #border_color
  sta $d020
  lda #bg_color
  sta $d021

  ; speed needs to be initialized before welcome_screen, so we do it here
  lda #speed_normal
  sta speed

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

  draw_stats score_text, 6, score, $07c0, 4
  draw_stats lives_text, 6, lives, $0400, 2

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

game_setup SUBROUTINE game_setup:
  lda #21
  sta 53272 ; uppercase/graphics mode

  lda legacy_mode
  beq .setup_normal

  ; legacy mode specific setup
  lda #$00
  sta score
  sta score+1
  lda #$24 ; 24 lives (BCD)
  sta lives
  jmp .setup_leg_out

.setup_normal: ; corresponding normal mode setup
  lda #$00
  sta score
  sta score+1
  lda #3
  sta lives
  jmp .setup_leg_out

.setup_leg_out:
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

round_setup SUBROUTINE round_setup:

  jsr draw_border

  lda legacy_mode
  beq .clean_normal

  ; legacy mode specific setup
  clean_field 15, 25, 10, 15
  jmp .clean_out

.clean_normal: ; corresponding normal mode setup
  clean_field 1, 39, 1, 24
  jmp .clean_out

.clean_out:

  lda #$5 ; initialize head and tail
  sta head_h
  lda #$f4
  sta head_l
  lda #$6
  sta tail_h
  lda #$1c
  sta tail_l

  ; snek direction
  lda #$0 ; 0 - north; 1 - east; 2 - south; 3 - west
  sta direction
  sta prev_dir
  sta tail_dir

  lda #$1 ; place a goodie directly after start of game
  sta do_spawn_goodie

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

  ; set SID voice 3 to noise, for random number generator
  lda #$ff
  sta $d40e
  sta $d40f
  lda #$80
  sta $d412

  ; initialize voice 1 for scoring sound
  lda #$12 ; frequency high byte
  sta $d401
  lda #$80 ; frequency low byte
  sta $d400
  lda #$07 ; AD
  sta $d405
  lda #$00 ; SR
  sta $d406

  ; initialize voice 2 for death sound
  lda #$35
  sta $d408
  lda #$99
  sta $d407
  lda #$0b ; AD
  sta $d40c
  lda #$00 ; SR
  sta $d40d

  lda #$0f ; SID volume (low nibble)
  sta $d418

  ; reset frame counter
  lda #0
  sta frame_ctr

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

irq: ; interrupt handler
  inc frame_ctr
  jsr read_input
  asl $d019 ; ack interrupt
  jmp $ea81 ; restore stack

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ts_irq: ; interrupt handler for title screen
  ; move sprites to the left
  sec
  lda ws_sprite_base
  sbc #1
  sta ws_sprite_base
  tax
  lda ws_sprite_base+1
  sbc #0
  sta ws_sprite_base+1
  bcs .no_wrap

  ; wrap around on underflow
  ; wrap around to 257. later, we "subtract" $200 again by setting $d010 bits only if y is 2.
  lda #$57
  sta ws_sprite_base
  tax
  lda #$2
  sta ws_sprite_base+1

.no_wrap:
  tay

  move_sprite 0
  move_sprite 1
  move_sprite 2
  move_sprite 3
  move_sprite 4
  move_sprite 5
  move_sprite 6
  move_sprite 7

  asl $d019
  jmp $ea81

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_input SUBROUTINE read_input:
  ; reads the joystick and adjusts the snek direction accordingly
  lda $dc01 ; joystick port 1
  tax

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
  lda prev_dir
  cmp #2
  beq .ignore
  lda #0
  sta direction
  rts
.down:
  lda prev_dir
  cmp #0
  beq .ignore
  lda #2
  sta direction
  rts
.left:
  lda prev_dir
  cmp #1
  beq .ignore
  lda #3
  sta direction
  rts
.right:
  lda prev_dir
  cmp #3
  beq .ignore
  lda #1
  sta direction
  rts

.ignore:
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

.move_out:

  ; check collision
  ldx #0 ; x will be set to 1 when a goodie is eaten
  ldy #0
  lda (head_l),y
  cmp #space_char
  beq .continue
  cmp #goodie_char
  beq .eat_goodie

  ; play death sound
  lda #death_vc
  sta $d40b
  lda #death_vc+1
  sta $d40b

  rts ; game over.

.eat_goodie:
  ldx #1
  stx do_spawn_goodie

  ; play scoring sound
  lda #score_vc
  sta $d404
  lda #score_vc+1 ; voice control register
  sta $d404

  ; increase score
  sed ; BCD mode
  lda score
  clc
  adc #1
  sta score
  lda score+1
  adc #0
  sta score+1
  cld

  draw_stats score_text, 6, score, $07c0, 4

.continue:

  ; draw new segment where head is
  lda #snek_head
  ldy #0
  sta (head_l),y

  ; advance tail if no goodie was eaten
  txa
  cmp #0
  beq .advance_tail ; branch over the jump because branch would be out of range
  jmp .dont_advance_tail
.advance_tail:

  lda tail_dir
  cmp #0
  beq .tail_north
  cmp #1
  beq .tail_east
  cmp #2
  beq .tail_south

  ; TODO this is really copy pasta. go and finally make a macro
  ; tail west
  sec
  lda tail_l
  sbc #1
  sta tail_l
  lda tail_h
  sbc #0
  sta tail_h
  jmp .tailmove_out

.tail_north:
  sec
  lda tail_l
  sbc #40
  sta tail_l
  lda tail_h
  sbc #0
  sta tail_h
  jmp .tailmove_out

.tail_east:
  clc
  lda tail_l
  adc #1
  sta tail_l
  lda tail_h
  adc #0
  sta tail_h
  jmp .tailmove_out

.tail_south:
  clc
  lda tail_l
  adc #40
  sta tail_l
  lda tail_h
  adc #0
  sta tail_h

.tailmove_out:
  ; set new tail direction according to the segment which is now under the tail
  ldy #0
  lda (tail_l),y

  cmp #snek_horz
  beq .tail_nochange
  cmp #snek_vert
  beq .tail_nochange ; tail is straight - no change in direction

  lda tail_dir
  cmp #0
  beq .tail_vert
  cmp #2
  beq .tail_vert

  ; tail must be going left or right - just check if it curves up or down
  lda (tail_l),y ; assumes y to still be 0
  cmp #snek_dl
  beq .newtail_south
  cmp #snek_dr
  beq .newtail_south
  jmp .newtail_north ; fallthrough snek_ul and snek_ur

.tail_vert: ; tail is going up or down - we just have to check if it curves left or right
  lda (tail_l),y ; assumes y to still be 0
  cmp #snek_dl
  beq .newtail_west
  cmp #snek_ul
  beq .newtail_west
  jmp .newtail_east ; fallthrough snek_ur and snek_dr

.newtail_north:
  lda #0
  jmp .newtail_out
.newtail_east:
  lda #1
  jmp .newtail_out
.newtail_south:
  lda #2
  jmp .newtail_out
.newtail_west:
  lda #3

.newtail_out:
  sta tail_dir

.tail_nochange:

.dont_advance_tail:

  jsr place_goodie

.skip_goodie:

  ; draw tail - do this after placing the goodie, so that goodie won't be placed in a spot where
  ; it can be deleted right away
  lda #space_char
  ldy #0
  sta (tail_l),y

.timer_loop:
  lda frame_ctr
  cmp speed
  bne .timer_loop
  lda #0
  sta frame_ctr

  jmp game_loop

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

place_goodie SUBROUTINE place_goodie:
  lda do_spawn_goodie
  cmp #0
  bne .do_it
  rts
.do_it:

  lda #30 ; try 30 times to spawn a goodie, then give up
  sta spawn_retry_count

.try_spawn:
  ; load random numbers from SID
  lda $d41b
  and #$0f ; 0..15
  clc
  adc #6 ; 6..21
  sta rnd_row
  lda $d41b
  and #$1f ; 0..31
  clc
  adc #4 ; 4..35
  sta rnd_col

  ; calculate goodie offset in screen
  ldx #$04 ; x as high byte
  ldy #$00 ; y as low byte

.row_loop:
  dec rnd_row ; it's never 0, so it's okay here to start with a dec
  beq .row_out
  tya
  clc
  adc #40
  tay
  txa
  adc #0
  tax
  jmp .row_loop
.row_out:
  tya
  clc
  adc rnd_col
  tay
  txa
  adc #0
  tax

  ; just use (63,64) as the pointer now
  stx $64
  sty $63

  ; make sure there's nothing where the goodie will be spawned
  ldy #0
  lda ($63),y
  cmp #space_char
  beq .spawn_okay

  dec spawn_retry_count
  beq .dont_place_a_goodie_now ; give up when retry count reaches zero
  jmp .try_spawn

.spawn_okay:
  lda #goodie_char
  ldy #0
  sta ($63),y

  lda #0
  sta do_spawn_goodie ; only reset if a goodie was actually spawned

.dont_place_a_goodie_now:

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  org $2000
  incbin "snek_title_short_bitmap.prg"

  org $3b00
  include "sprites.asm"

  org $3d40
  incbin "snek_title_short_charmem.prg"

  org $4088
  incbin "snek_title_short_colormem.prg"
