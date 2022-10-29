org 0x7C00
bits 16


BG_COLOR equ 0x12
BALL_COLOR equ 0x75
PANEL_COLOR equ 0x35
SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
SCALE equ 5
PANEL_WIDTH equ 1
PANEL_HEIGHT equ 4
DELAY equ 1
_start:
	jmp main



xBall: dw 20
yBall: dw 20																	;        RLDU
dire: dw 0b0110 ; we only use the last two bytes to determinields word: 0000XXXX
ball_color: dw BALL_COLOR
panel_color: dw PANEL_COLOR
xPanel: dw 62 ;this should not be modified
yPanel: dw 20
playerScore: dw 0
rivalScore: dw 0
xRival: dw 1
yRival: dw 20



main:
	cli 	
	;setup segments

	xor ax,ax
	mov ds,ax
	mov ss,ax
	mov es,ax
	mov sp,0x7C00
	mov bp,sp
	sti

	
	
	;loading the game from disk bc its too large to compress in one sector 
	
	mov ah,0x02
	mov al,0x04 ; numbers of sectors to be read
	mov ch,0x00
	mov cl,0x2
	mov dh,0
	mov bx, loaded_game
	int 0x13
	
	jmp loaded_game

times 510 -($-$$) db 0

dw 0xaa55

loaded_game:
	mov al ,0x3
	mov ah,0x5
	mov bh,0
	mov bl,0
	int 0x16


	mov ah,0 ; set up video mode
	mov al,0x13 ; 256 colors 320*200 VGA video mode
	int 0x10
	
;set up video memory, begins at 0xB800
	push 0xA000
	pop es

.main_loop:


;process input

;first we look at the keyboard status ,if its not clicked we reduce the overhead and jump directly to the update section

	mov ah,1
	int 0x16
	jz .skip_input

	mov ax,0
	int 0x16

	;the ascii input is in the al register

	cmp al,'w'
	jne .next_key
	dec word [yPanel]
	dec word [yPanel]
	cmp word [yPanel],0
	jge .skip_input
	mov word [yPanel],0
	jmp .skip_input
.next_key:
	cmp al,'s'
	jne .skip_input
	inc word [yPanel]
	inc word [yPanel]
	cmp word [yPanel],40-PANEL_HEIGHT
	jle .skip_input
	mov word [yPanel],40-PANEL_HEIGHT

;------------------------------------------

;update the movment of the rival

.skip_input:

	mov bx,word [yRival]
	mov cx,word [dire]
	bt cx,2
	jc .ball_left

.go_to_center:
	;if the ball is heading right the rival just goes to the center	
	cmp bx,18
	jl .inc
	cmp bx,18
	je .skip_input0
	dec word [yRival]
	cmp word [yRival],0
	jge .skip_input0
	mov word [yRival],0
	jmp .skip_input0
.inc:

	inc word [yRival]
	cmp  word [yRival],36
	jle .skip_input0
	mov word [yRival],36
	jmp .skip_input0

.ball_left:
	;the ball is going towards the rival

	cmp word [xBall],32
	jl .follow_the_ball
	
	jmp .go_to_center
	
.follow_the_ball:

	cmp bx, word [yBall]
	jl .inc0
	
	dec word [yRival]
	cmp word [yRival],0
	jge .skip_input0
	mov word [yRival] ,0
	jmp .skip_input0
.inc0:
	inc word [yRival]
	cmp word [yRival],36
	jle .skip_input0
	mov word [yRival],36
	jmp .skip_input0

;------------------------------------------

.skip_input0:
	;clear background
	mov cx,64000
	mov al,BG_COLOR
	xor di,di
	rep stosb
;------------------------------------
; draw the panel player 5*1 x 5*4

	mov ax,word [yPanel]
	mov bx,word [xPanel]
	imul di , ax, SCALE*SCREEN_WIDTH
	imul dx, bx, SCALE
	add di ,dx
	mov cx,SCALE
	mov ax,word [panel_color]
	xor dx,dx
.loop_panel:
	rep stosb
	add di,SCREEN_WIDTH
	mov cx,SCALE
	sub di,SCALE
	inc dx
	cmp dx,PANEL_HEIGHT*SCALE
	jl .loop_panel

;------------------------------------
; draw the rival 5*1 x 5*4

	mov ax,word [yRival]
	mov bx,word [xRival]
	imul di , ax, SCALE*SCREEN_WIDTH
	imul dx, bx, SCALE
	add di ,dx
	mov cx,SCALE
	mov ax,word [panel_color]
	xor dx,dx
.loop_rival:
	rep stosb
	add di,SCREEN_WIDTH
	mov cx,SCALE
	sub di,SCALE
	inc dx
	cmp dx,PANEL_HEIGHT*SCALE
	jl .loop_rival


;------------------------------------
	;draw the ball
	
	imul di,word [yBall], SCREEN_WIDTH*SCALE
	imul dx, word[xBall],SCALE
	add di,dx
	xor dx,dx
	mov ax,word [ball_color]
	mov cx,SCALE

.loop:
	rep stosb
	add di,SCREEN_WIDTH
	add cx,5
	sub di,cx
	inc dx
	cmp dx,5
	jl .loop

	
;-------------------------------------

.update_game:

;update the game 
;check the borders and reverse the direction

	mov ax, word [xBall]; x coordinates
	mov bx, word [yBall]; y coordinates
	mov cx, word [dire] ; cx = 00000000000000XX

	;before checking the borders we need to check the collisions with our panel


	cmp ax,61
	jl .check_rival
	cmp ax,62		        ;checking the X axis
	jg .check_rival

	mov dx,word [yPanel]
	dec dx
	cmp bx,dx
	jl .check_rival
							;checking the Y axis	
	mov dx,word[yPanel]
	add dx,PANEL_HEIGHT
	cmp bx,dx
	jg .check_rival

	; at this point the collision is detected 

;----------------------------------------------------------------	
	cmp ax,61
	jne .check_middle
;at this point the ball is the right side of the panel

	mov dx,word [yPanel]
	dec dx 
	cmp dx,bx
	jne .skp0 ;comparing with the top corner
	cmp cx,0b1010
	jne .update_coordinates
	mov cx,0b0101
	mov word [dire],cx
	jmp .update_coordinates
	

.skp0:
	add dx,PANEL_HEIGHT+1 ;comparing with the down corner
	cmp bx,dx
	jne .skp1
	cmp cx,0b1001
	jne .update_coordinates
	mov cx,0b0110
	mov word [dire],cx
	jmp .update_coordinates
.skp1:
	;the rest of the probabilities
	
	xor cx,0b1100
	mov word [dire],cx
	jmp .update_coordinates



;--------------------------------------------------

.check_middle:

	cmp ax,62
	jne .check_border

	mov dx,word [yPanel]
	dec dx
	cmp dx,bx
	jne .next_check1
	
	
	bt cx,1
	jnc .update_coordinates	

	xor cx,0b0011
	mov word [dire],cx
	jmp .update_coordinates

.next_check1:
	mov dx,word [yPanel]
	add dx,PANEL_HEIGHT
	cmp dx,bx

	jne .update_coordinates
	
	bt cx,0
	jnc .update_coordinates

	xor cx,0b0011
	mov word [dire],cx
	jmp .update_coordinates



;----------------------------------------------------------------

.check_rival:

	cmp ax,1
	jl .check_border
	cmp ax,2		        ;checking the X axis
	jg .check_border

	mov dx,word [yRival]
	dec dx
	cmp bx,dx
	jl .check_border
							;checking the Y axis	
	mov dx,word[yRival]
	add dx,PANEL_HEIGHT
	cmp bx,dx
	jg .check_border

	; at this point the collision is detected 
	;and we need to do something about it (it seems hard)

;----------------------------------------------------------------	
	cmp ax,2
	jne .rcheck_middle
;at this point the ball is the left side of the panel

	mov dx,word [yRival]
	dec dx 
	cmp dx,bx
	jne .rskp0 ;comparing with the top corner
	cmp cx,0b0110
	jne .update_coordinates
	mov cx,0b1001
	mov word [dire],cx
	jmp .update_coordinates
	

.rskp0:
	add dx,PANEL_HEIGHT+1 ;comparing with the down corner
	cmp bx,dx
	jne .rskp1
	cmp cx,0b0101
	jne .update_coordinates
	mov cx,0b1010
	mov word [dire],cx
	jmp .update_coordinates
.rskp1:
	;the rest of the probabilities
	
	xor cx,0b1100
	mov word [dire],cx
	jmp .update_coordinates



;--------------------------------------------------

.rcheck_middle:

	cmp ax,0
	jne .check_border

	mov dx,word [yRival]
	dec dx
	cmp dx,bx
	jne .rnext_check1
	jnc .update_coordinates	

	xor cx,0b0011
	mov word [dire],cx
	jmp .update_coordinates

.rnext_check1:
	mov dx,word [yRival]
	add dx,PANEL_HEIGHT
	cmp dx,bx

	jne .update_coordinates
	
	bt cx,0
	jnc .update_coordinates

	xor cx,0b0011
	mov word [dire],cx
	jmp .update_coordinates


.check_border:

	; ax -> x coordinates
	; bx -> y coordinates
	mov ax, word [xBall]
	mov bx, word [yBall]
	mov cx, word [dire]

	cmp ax,0
	jne .skip0
	bt cx,2
	jnc .update_coordinates
	mov cx,0b1010
	mov word [dire],cx
	mov word[xBall],32
	mov word[yBall],20
	jmp .update_coordinates
.skip0:
	cmp ax,63
	jne .skip1
	bt cx,3 ; checking the right index
	jnc .update_coordinates
	mov cx,0b1010
	mov word [dire],cx
	mov word[xBall],32
	mov word[yBall],20
;y coordinates
.skip1:
	cmp bx,0
	jne .skip2
	bt cx,1
	jc .update_coordinates
	xor cx,0b0011
	mov word [dire],cx
.skip2:
	cmp bx,39
	jne .update_coordinates
	bt cx,1
	jnc .update_coordinates
	xor cx,0b0011
	mov word [dire],cx
.update_coordinates:
	
	mov cx, word [dire]
	bt cx,0
	jnc .s0
	dec word [yBall]
	jmp .s1
.s0:
	bt cx,1
	jnc .s1
	inc word [yBall]
.s1:
;right left 
	bt cx,2
	jnc .s2
	dec word [xBall]
	jmp .s3
.s2:
	bt cx,3
	jnc .s3
	inc word [xBall]
.s3:


;-------------------------------------

;delay

	
	mov ah,0
	int 0x1A
	add dx,DELAY
	push dx
.loop_delay:
	mov ah,0
	int 0x1A
	cmp dx,[bp-2]
	jb .loop_delay
	add sp,2 

jmp .main_loop

