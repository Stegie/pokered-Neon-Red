_GivePokemon: ; 4fda5 (13:7da5)
	call EnableAutoTextBoxDrawing
	xor a
	ld [wccd3], a
	ld a, [wPartyCount] ; wPartyCount
	cp $6
	jr c, .asm_4fe01
	ld a, [W_NUMINBOX] ; wda80
	cp $14
	jr nc, .asm_4fdf9
	xor a
	ld [W_ENEMYBATTSTATUS3], a ; W_ENEMYBATTSTATUS3
	ld a, [wcf91]
	ld [wEnemyMonSpecies2], a
	callab Func_3eb01
	call SetPokedexOwnedFlag
	callab Func_e7a4
	ld hl, wcf4b
	ld a, [wd5a0]
	and $7f
	cp $9
	jr c, .asm_4fdec
	sub $9
	ld [hl], $f7
	inc hl
	add $f6
	jr .asm_4fdee
.asm_4fdec
	add $f7
.asm_4fdee
	ld [hli], a
	ld [hl], $50
	ld hl, SetToBoxText
	call PrintText
	scf
	ret
.asm_4fdf9
	ld hl, BoxIsFullText
	call PrintText
	and a
	ret
.asm_4fe01
	call SetPokedexOwnedFlag
	call AddPartyMon
	ld a, $1
	ld [wcc3c], a
	ld [wccd3], a
	scf
	ret

SetPokedexOwnedFlag: ; 4fe11 (13:7e11)
	ld a, [wcf91]
	push af
	ld [wd11e], a
	predef IndexToPokedex
	ld a, [wd11e]
	dec a
	ld c, a
	ld hl, wPokedexOwned ; wPokedexOwned
	ld b, $1
	predef FlagActionPredef
	pop af
	ld [wd11e], a
	call GetMonName
	ld hl, GotMonText
	jp PrintText

GotMonText: ; 4fe39 (13:7e39)
	TX_FAR _GotMonText
	db $0b
	db "@"

SetToBoxText: ; 4fe3f (13:7e3f)
	TX_FAR _SetToBoxText
	db "@"

BoxIsFullText: ; 4fe44 (13:7e44)
	TX_FAR _BoxIsFullText
	db "@"
