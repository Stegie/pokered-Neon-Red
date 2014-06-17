HandleLedges: ; 1a672 (6:6672)
	ld a, [wd736]
	bit 6, a
	ret nz
	ld a, [W_CURMAPTILESET] ; W_CURMAPTILESET
	and a ; OVERWORLD
	ret nz
	predef Func_c586
	ld a, [wSpriteStateData1 + 9]
	ld b, a
	FuncCoord 8, 9
	ld a, [Coord]
	ld c, a
	ld a, [wcfc6]
	ld d, a
	ld hl, LedgeTiles ; $66cf
.asm_1a691
	ld a, [hli]
	cp $ff
	ret z
	cp b
	jr nz, .asm_1a6a4
	ld a, [hli]
	cp c
	jr nz, .asm_1a6a5
	ld a, [hli]
	cp d
	jr nz, .asm_1a6a6
	ld a, [hl]
	ld e, a
	jr .asm_1a6a9
.asm_1a6a4
	inc hl
.asm_1a6a5
	inc hl
.asm_1a6a6
	inc hl
	jr .asm_1a691
.asm_1a6a9
	ld a, [hJoyHeld]
	and e
	ret z
	ld a, $ff
	ld [wJoyIgnore], a
	ld hl, wd736
	set 6, [hl]
	call Func_3486
	ld a, e
	ld [wccd3], a
	ld [wccd4], a
	ld a, $2
	ld [wcd38], a
	call LoadHoppingShadowOAM
	ld a, (SFX_02_4e - SFX_Headers_02) / 3
	call PlaySound
	ret

	; (player direction) (tile player standing on) (ledge tile) (input required)
LedgeTiles: ; 1a6cf (6:66cf)
	db $00,$2C,$37,$80
	db $00,$39,$36,$80
	db $00,$39,$37,$80
	db $08,$2C,$27,$20
	db $08,$39,$27,$20
	db $0C,$2C,$0D,$10
	db $0C,$2C,$1D,$10
	db $0C,$39,$0D,$10
	db $FF

LoadHoppingShadowOAM: ; 1a6f0 (6:66f0)
	ld hl, vChars1 + $7f0
	ld de, LedgeHoppingShadow ; $6708
	ld bc, (BANK(LedgeHoppingShadow) << 8) + $01
	call CopyVideoDataDouble
	ld a, $9
	ld bc, $5448 ; b, c = y, x coordinates of shadow
	ld de, LedgeHoppingShadowOAM ; $6710
	call WriteOAMBlock
	ret

LedgeHoppingShadow: ; 1a708 (6:6708)
	INCBIN "gfx/ledge_hopping_shadow.1bpp"

LedgeHoppingShadowOAM: ; 1a710 (6:6710)
	db $FF,$10,$FF,$20
	db $FF,$40,$FF,$60
