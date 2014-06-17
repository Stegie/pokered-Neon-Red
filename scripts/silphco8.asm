SilphCo8Script: ; 56504 (15:6504)
	call SilphCo8Script_5651a
	call EnableAutoTextBoxDrawing
	ld hl, SilphCo8TrainerHeader0
	ld de, SilphCo8ScriptPointers
	ld a, [W_SILPHCO8CURSCRIPT]
	call ExecuteCurMapScriptInTable
	ld [W_SILPHCO8CURSCRIPT], a
	ret

SilphCo8Script_5651a: ; 5651a (15:651a)
	ld hl, wd126
	bit 5, [hl]
	res 5, [hl]
	ret z
	ld hl, DataTable_5653e ; $653e
	call SilphCo8Script_56541
	call SilphCo8Script_5656d
	ld a, [wd832]
	bit 0, a
	ret nz
	ld a, $5f
	ld [wd09f], a
	ld bc, $403
	predef_jump Func_ee9e

DataTable_5653e: ; 5653e (15:653e)
	db $04,$03,$FF

SilphCo8Script_56541: ; 56541 (15:6541)
	push hl
	ld hl, wd73f
	ld a, [hli]
	ld b, a
	ld a, [hl]
	ld c, a
	xor a
	ld [$ffe0], a
	pop hl
.asm_5654d
	ld a, [hli]
	cp $ff
	jr z, .asm_56569
	push hl
	ld hl, $ffe0
	inc [hl]
	pop hl
	cp b
	jr z, .asm_5655e
	inc hl
	jr .asm_5654d
.asm_5655e
	ld a, [hli]
	cp c
	jr nz, .asm_5654d
	ld hl, wd73f
	xor a
	ld [hli], a
	ld [hl], a
	ret
.asm_56569
	xor a
	ld [$ffe0], a
	ret

SilphCo8Script_5656d: ; 5656d (15:656d)
	ld a, [$ffe0]
	and a
	ret z
	ld hl, wd832
	set 0, [hl]
	ret

SilphCo8ScriptPointers: ; 56577 (15:6577)
	dw CheckFightingMapTrainers
	dw Func_324c
	dw EndTrainerBattle

SilphCo8TextPointers: ; 5657d (15:657d)
	dw SilphCo8Text1
	dw SilphCo8Text2
	dw SilphCo8Text3
	dw SilphCo8Text4

SilphCo8TrainerHeaders: ; 56585 (15:6585)
SilphCo8TrainerHeader0: ; 56585 (15:6585)
	db $2 ; flag's bit
	db ($4 << 4) ; trainer's view range
	dw wd831 ; flag's byte
	dw SilphCo8BattleText1 ; 0x65e6 TextBeforeBattle
	dw SilphCo8AfterBattleText1 ; 0x65f0 TextAfterBattle
	dw SilphCo8EndBattleText1 ; 0x65eb TextEndBattle
	dw SilphCo8EndBattleText1 ; 0x65eb TextEndBattle

SilphCo8TrainerHeader1: ; 56591 (15:6591)
	db $3 ; flag's bit
	db ($4 << 4) ; trainer's view range
	dw wd831 ; flag's byte
	dw SilphCo8BattleText2 ; 0x65f5 TextBeforeBattle
	dw SilphCo8AfterBattleText2 ; 0x65ff TextAfterBattle
	dw SilphCo8EndBattleText2 ; 0x65fa TextEndBattle
	dw SilphCo8EndBattleText2 ; 0x65fa TextEndBattle

SilphCo8TrainerHeader2: ; 5659d (15:659d)
	db $4 ; flag's bit
	db ($4 << 4) ; trainer's view range
	dw wd831 ; flag's byte
	dw SilphCo8BattleText3 ; 0x6604 TextBeforeBattle
	dw SilphCo8AfterBattleText3 ; 0x660e TextAfterBattle
	dw SilphCo8EndBattleText3 ; 0x6609 TextEndBattle
	dw SilphCo8EndBattleText3 ; 0x6609 TextEndBattle

	db $ff

SilphCo8Text1: ; 565aa (15:65aa)
	db $08 ; asm
	ld a, [wd838]
	bit 7, a
	ld hl, SilphCo8Text_565c3
	jr nz, asm_a468f ; 0x565b3
	ld hl, SilphCo8Text_565be
asm_a468f ; 0x565b8
	call PrintText
	jp TextScriptEnd

SilphCo8Text_565be: ; 565be (15:65be)
	TX_FAR _SilphCo8Text_565be
	db "@"

SilphCo8Text_565c3: ; 565c3 (15:65c3)
	TX_FAR _SilphCo8Text_565c3
	db "@"

SilphCo8Text2: ; 565c8 (15:65c8)
	db $08 ; asm
	ld hl, SilphCo8TrainerHeader0
	call TalkToTrainer
	jp TextScriptEnd

SilphCo8Text3: ; 565d2 (15:65d2)
	db $08 ; asm
	ld hl, SilphCo8TrainerHeader1
	call TalkToTrainer
	jp TextScriptEnd

SilphCo8Text4: ; 565dc (15:65dc)
	db $08 ; asm
	ld hl, SilphCo8TrainerHeader2
	call TalkToTrainer
	jp TextScriptEnd

SilphCo8BattleText1: ; 565e6 (15:65e6)
	TX_FAR _SilphCo8BattleText1
	db "@"

SilphCo8EndBattleText1: ; 565eb (15:65eb)
	TX_FAR _SilphCo8EndBattleText1
	db "@"

SilphCo8AfterBattleText1: ; 565f0 (15:65f0)
	TX_FAR _SilphCo8AfterBattleText1
	db "@"

SilphCo8BattleText2: ; 565f5 (15:65f5)
	TX_FAR _SilphCo8BattleText2
	db "@"

SilphCo8EndBattleText2: ; 565fa (15:65fa)
	TX_FAR _SilphCo8EndBattleText2
	db "@"

SilphCo8AfterBattleText2: ; 565ff (15:65ff)
	TX_FAR _SilphCo8AfterBattleText2
	db "@"

SilphCo8BattleText3: ; 56604 (15:6604)
	TX_FAR _SilphCo8BattleText3
	db "@"

SilphCo8EndBattleText3: ; 56609 (15:6609)
	TX_FAR _SilphCo8EndBattleText3
	db "@"

SilphCo8AfterBattleText3: ; 5660e (15:660e)
	TX_FAR _SilphCo8AfterBattleText3
	db "@"
