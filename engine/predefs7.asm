Func_1c9c6: ; 1c9c6 (7:49c6)
	ld hl, WhichFloorText
	call PrintText
	ld hl, wStringBuffer2 + 11
	ld a, l
	ld [wcf8b], a
	ld a, h
	ld [wcf8c], a
	ld a, [wListScrollOffset] ; wcc36
	push af
	xor a
	ld [wCurrentMenuItem], a ; wCurrentMenuItem
	ld [wListScrollOffset], a ; wcc36
	ld [wcf93], a
	ld a, $4
	ld [wListMenuID], a ; wListMenuID
	call DisplayListMenuID
	pop bc
	ld a, b
	ld [wListScrollOffset], a ; wcc36
	ret c
	ld hl, wd126
	set 7, [hl]
	ld hl, wcc5b
	ld a, [wWhichPokemon] ; wWhichPokemon
	add a
	ld d, $0
	ld e, a
	add hl, de
	ld a, [hli]
	ld b, a
	ld a, [hl]
	ld c, a
	ld hl, wd3af
	call Func_1ca0d

Func_1ca0d: ; 1ca0d (7:4a0d)
	inc hl
	inc hl
	ld a, b
	ld [hli], a
	ld a, c
	ld [hli], a
	ret

WhichFloorText: ; 1ca14 (7:4a14)
	TX_FAR _WhichFloorText
	db "@"
