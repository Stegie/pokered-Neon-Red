HallOfFamePC: ; 7405c (1d:405c)
	callba AnimateHallOfFame
	call ClearScreen
	ld c, $64
	call DelayFrames
	call DisableLCD
	ld hl, vFont
	ld bc, $800 / 2
	call Func_74171
	ld hl, vChars2 + $600
	ld bc, $200 / 2
	call Func_74171
	ld hl, vChars2 + $7e0
	ld bc, $10
	ld a, $ff
	call FillMemory
	ld hl, wTileMap
	call Func_7417b
	FuncCoord 0, 14
	ld hl, Coord
	call Func_7417b
	ld a, $c0
	ld [rBGP], a ; $ff47
	call EnableLCD
	ld a, $ff
	call PlaySoundWaitForCurrent
	ld c, BANK(Music_Credits)
	ld a, MUSIC_CREDITS
	call PlayMusic
	ld c, $80
	call DelayFrames
	xor a
	ld [wWhichTrade], a ; wWhichTrade
	ld [wTrainerEngageDistance], a
	jp Credits

Func_740ba: ; 740ba (1d:40ba)
	ld hl, DataTable_74160 ; $4160
	ld b, $4
.asm_740bf
	ld a, [hli]
	ld [rBGP], a ; $ff47
	ld c, $5
	call DelayFrames
	dec b
	jr nz, .asm_740bf
	ret

DisplayCreditsMon: ; 740cb (1d:40cb)
	xor a
	ld [H_AUTOBGTRANSFERENABLED],a
	call SaveScreenTilesToBuffer1
	call FillMiddleOfScreenWithWhite

	; display the next monster from CreditsMons
	ld hl,wTrainerEngageDistance
	ld c,[hl] ; how many monsters have we displayed so far?
	inc [hl]
	ld b,0
	ld hl,CreditsMons
	add hl,bc ; go that far in the list of monsters and get the next one
	ld a,[hl]
	ld [wcf91],a
	ld [wd0b5],a
	FuncCoord 8, 6
	ld hl,Coord
	call GetMonHeader
	call LoadFrontSpriteByMonIndex
	ld hl,vBGMap0 + $c
	call Func_74164
	xor a
	ld [H_AUTOBGTRANSFERENABLED],a
	call LoadScreenTilesFromBuffer1
	ld hl,vBGMap0
	call Func_74164
	ld a,$A7
	ld [$FF4B],a
	ld hl,vBGMap1
	call Func_74164
	call FillMiddleOfScreenWithWhite
	ld a,$FC
	ld [$FF47],a
	ld bc,7
.next
	call Func_74140
	dec c
	jr nz,.next
	ld c,$14
.next2
	call Func_74140
	ld a,[$FF4B]
	sub 8
	ld [$FF4B],a
	dec c
	jr nz,.next2
	xor a
	ld [$FFB0],a
	ld a,$C0
	ld [$FF47],a
	ret

INCLUDE "data/credit_mons.asm"

Func_74140: ; 74140 (1d:4140)
	ld h, b
	ld l, $20
	call Func_74152
	ld h, $0
	ld l, $70
	call Func_74152
	ld a, b
	add $8
	ld b, a
	ret

Func_74152: ; 74152 (1d:4152)
	ld a, [$ff44]
	cp l
	jr nz, Func_74152
	ld a, h
	ld [rSCX], a ; $ff43
.asm_7415a
	ld a, [$ff44]
	cp h
	jr z, .asm_7415a
	ret

DataTable_74160: ; 74160 (1d:4160)
	db $C0,$D0,$E0,$F0

Func_74164: ; 74164 (1d:4164)
	ld a, l
	ld [H_AUTOBGTRANSFERDEST], a ; $ffbc
	ld a, h
	ld [$ffbd], a
	ld a, $1
	ld [H_AUTOBGTRANSFERENABLED], a ; $ffba
	jp Delay3

Func_74171: ; 74171 (1d:4171)
	ld [hl], $0
	inc hl
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, Func_74171
	ret

Func_7417b: ; 7417b (1d:417b)
	ld bc, $50
	ld a, $7e
	jp FillMemory

FillMiddleOfScreenWithWhite: ; 74183 (1d:4183)
	FuncCoord 0, 4
	ld hl, Coord
	ld bc, $c8 ; 10 rows of 20 tiles each
	ld a, $7f ; blank white tile
	jp FillMemory

Credits: ; 7418e (1d:418e)
	ld de, CreditsOrder ; $4243
	push de
.asm_74192
	pop de
	FuncCoord 9, 6
	ld hl, Coord
	push hl
	call FillMiddleOfScreenWithWhite
	pop hl
.asm_7419b
	ld a, [de]
	inc de
	push de
	cp $ff
	jr z, .asm_741d5
	cp $fe
	jr z, .asm_741dc
	cp $fd
	jr z, .asm_741e6
	cp $fc
	jr z, .asm_741ed
	cp $fb
	jr z, .asm_741f4
	cp $fa
	jr z, .showTheEnd
	push hl
	push hl
	ld hl, CreditsTextPointers ; $42c3
	add a
	ld c, a
	ld b, $0
	add hl, bc
	ld e, [hl]
	inc hl
	ld d, [hl]
	ld a, [de]
	inc de
	ld c, a
	ld b, $ff
	pop hl
	add hl, bc
	call PlaceString
	pop hl
	ld bc, $28
	add hl, bc
	pop de
	jr .asm_7419b
.asm_741d5
	call Func_740ba
	ld c, $5a
	jr .asm_741de
.asm_741dc
	ld c, $6e
.asm_741de
	call DelayFrames
	call DisplayCreditsMon
	jr .asm_74192
.asm_741e6
	call Func_740ba
	ld c, $78
	jr .asm_741ef
.asm_741ed
	ld c, $8c
.asm_741ef
	call DelayFrames
	jr .asm_74192
.asm_741f4
	push de
	callba LoadCopyrightTiles
	pop de
	pop de
	jr .asm_7419b
.showTheEnd
	ld c, $10
	call DelayFrames
	call FillMiddleOfScreenWithWhite
	pop de
	ld de, TheEndGfx
	ld hl, vChars2 + $600
	ld bc, (BANK(TheEndGfx) << 8) + $0a
	call CopyVideoData
	FuncCoord 4, 8
	ld hl, Coord
	ld de, TheEndTextString
	call PlaceString
	FuncCoord 4, 9
	ld hl, Coord
	inc de
	call PlaceString
	jp Func_740ba

TheEndTextString: ; 74229 (1d:4229)
; "T H E  E N D"
	db $60," ",$62," ",$64,"  ",$64," ",$66," ",$68,"@"
	db $61," ",$63," ",$65,"  ",$65," ",$67," ",$69,"@"

INCLUDE "data/credits_order.asm"

INCLUDE "text/credits_text.asm"

TheEndGfx: ; 7473e (1d:473e) ; 473E (473F on blue)
	INCBIN "gfx/theend.interleave.2bpp"
