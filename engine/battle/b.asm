DisplayEffectiveness: ; 2fb7b (b:7b7b)
	ld a, [wd05b]
	and a, $7F
	cp a, $0A
	ret z
	ld hl, SupperEffectiveText
	jr nc, .done
	ld hl, NotVeryEffectiveText
.done
	jp PrintText

SupperEffectiveText: ; 2fb8e (b:7b8e)
	TX_FAR _SupperEffectiveText
	db "@"

NotVeryEffectiveText: ; 2fb93 (b:7b93)
	TX_FAR _NotVeryEffectiveText
	db "@"
