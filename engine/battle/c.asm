MistEffect_: ; 33f2b (c:7f2b)
	ld hl, W_PLAYERBATTSTATUS2
	ld a, [$fff3]
	and a
	jr z, .asm_33f36
	ld hl, W_ENEMYBATTSTATUS2
.asm_33f36
	bit 1, [hl] ; is mon protected by mist?
	jr nz, .asm_33f4a
	set 1, [hl] ; mon is now protected by mist
	callab Func_3fba8
	ld hl, ShroudedInMistText
	jp PrintText
.asm_33f4a
	ld hl, PrintButItFailedText_
	ld b, BANK(PrintButItFailedText_)
	jp Bankswitch

ShroudedInMistText: ; 33f52 (c:7f52)
	TX_FAR _ShroudedInMistText
	db "@"

OneHitKOEffect_: ; 33f57 (c:7f57)
	ld hl, W_DAMAGE ; W_DAMAGE
	xor a
	ld [hli], a
	ld [hl], a ; set the damage output to zero
	dec a
	ld [wd05e], a
	ld hl, wBattleMonSpeed + 1
	ld de, wEnemyMonSpeed + 1
	ld a, [H_WHOSETURN] ; $fff3
	and a
	jr z, .asm_33f72
	ld hl, wEnemyMonSpeed + 1
	ld de, wBattleMonSpeed + 1
.asm_33f72
	ld a, [de]
	dec de
	ld b, a
	ld a, [hld]
	sub b
	ld a, [de]
	ld b, a
	ld a, [hl]
	sbc b
	jr c, .asm_33f8a
	ld hl, W_DAMAGE ; W_DAMAGE
	ld a, $ff
	ld [hli], a
	ld [hl], a
	ld a, $2
	ld [wd05e], a
	ret
.asm_33f8a
	ld a, $1
	ld [W_MOVEMISSED], a ; W_MOVEMISSED
	ret
