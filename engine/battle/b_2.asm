; scales both uncompressed sprite chunks by two in every dimension (creating 2x2 output pixels per input pixel)
; assumes that input sprite chunks are 4x4 tiles, and the rightmost and bottommost 4 pixels will be ignored
; resulting in a 7*7 tile output sprite chunk
ScaleSpriteByTwo: ; 2fe40 (b:7e40)
	ld de, S_SPRITEBUFFER1 + (4*4*8) - 5          ; last byte of input data, last 4 rows already skipped
	ld hl, S_SPRITEBUFFER0 + SPRITEBUFFERSIZE - 1 ; end of destination buffer
	call ScaleLastSpriteColumnByTwo               ; last tile column is special case
	call ScaleFirstThreeSpriteColumnsByTwo        ; scale first 3 tile columns
	ld de, S_SPRITEBUFFER2 + (4*4*8) - 5          ; last byte of input data, last 4 rows already skipped
	ld hl, S_SPRITEBUFFER1 + SPRITEBUFFERSIZE - 1 ; end of destination buffer
	call ScaleLastSpriteColumnByTwo               ; last tile column is special case

ScaleFirstThreeSpriteColumnsByTwo: ; 2fe55 (b:7e55)
	ld b, $3 ; 3 tile columns
.columnLoop
	ld c, 4*8 - 4 ; $1c, 4 tiles minus 4 unused rows
.columnInnerLoop
	push bc
	ld a, [de]
	ld bc, -(7*8)+1       ; $ffc9, scale lower nybble and seek to previous output column
	call ScalePixelsByTwo
	ld a, [de]
	dec de
	swap a
	ld bc, 7*8+1-2        ; $37, scale upper nybble and seek back to current output column and to the next 2 rows
	call ScalePixelsByTwo
	pop bc
	dec c
	jr nz, .columnInnerLoop
	dec de
	dec de
	dec de
	dec de
	ld a, b
	ld bc, -7*8 ; $ffc8, skip one output column (which has already been written along with the current one)
	add hl, bc
	ld b, a
	dec b
	jr nz, .columnLoop
	ret

ScaleLastSpriteColumnByTwo: ; 2fe7d (b:7e7d)
	ld a, 4*8 - 4 ; $1c, 4 tiles minus 4 unused rows
	ld [H_SPRITEINTERLACECOUNTER], a ; $ff8b
	ld bc, -1 ; $ffff
.columnInnerLoop
	ld a, [de]
	dec de
	swap a                    ; only high nybble contains information
	call ScalePixelsByTwo
	ld a, [H_SPRITEINTERLACECOUNTER] ; $ff8b
	dec a
	ld [H_SPRITEINTERLACECOUNTER], a ; $ff8b
	jr nz, .columnInnerLoop
	dec de                    ; skip last 4 rows of new column
	dec de
	dec de
	dec de
	ret

; scales the given 4 bits in a (4x1 pixels) to 2 output bytes (8x2 pixels)
; hl: destination pointer
; bc: destination pointer offset (added after the two bytes have been written)
ScalePixelsByTwo: ; 2fe97 (b:7e97)
	push hl
	and $f
	ld hl, DuplicateBitsTable
	add l
	ld l, a
	jr nc, .noCarry
	inc h
.noCarry
	ld a, [hl]
	pop hl
	ld [hld], a  ; write output byte twice to make it 2 pixels high
	ld [hl], a
	add hl, bc   ; add offset
	ret

; repeats each input bit twice
DuplicateBitsTable: ; 2fea8 (b:7ea8)
	db $00, $03, $0c, $0f
	db $30, $33, $3c, $3f
	db $c0, $c3, $cc, $cf
	db $f0, $f3, $fc, $ff

PayDayEffect_ ; 2feb8 (b:7eb8)
	xor a
	ld hl, wcd6d
	ld [hli], a
	ld a, [$fff3]
	and a
	ld a, [wBattleMonLevel]
	jr z, .asm_2fec8 ; 0x2fec3 $3
	ld a, [wEnemyMonLevel]
.asm_2fec8
	add a
	ld [$ff98], a
	xor a
	ld [$ff95], a
	ld [$ff96], a
	ld [$ff97], a
	ld a, $64
	ld [$ff99], a
	ld b, $4
	call Divide
	ld a, [$ff98]
	ld [hli], a
	ld a, [$ff99]
	ld [$ff98], a
	ld a, $a
	ld [$ff99], a
	ld b, $4
	call Divide
	ld a, [$ff98]
	swap a
	ld b, a
	ld a, [$ff99]
	add b
	ld [hl], a
	ld de, wcce7
	ld c, $3
	predef AddBCDPredef
	ld hl, CoinsScatteredText ; $7f04
	jp PrintText

CoinsScatteredText: ; 2ff04 (b:7f04)
	TX_FAR _CoinsScatteredText
	db "@"
