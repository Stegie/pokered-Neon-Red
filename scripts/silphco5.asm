SilphCo5Script: ; 19f37 (6:5f37)
	call SilphCo5Script_19f4d
	call EnableAutoTextBoxDrawing
	ld hl, SilphCo5TrainerHeaders
	ld de, SilphCo5ScriptPointers
	ld a, [W_SILPHCO5CURSCRIPT]
	call ExecuteCurMapScriptInTable
	ld [W_SILPHCO5CURSCRIPT], a
	ret

SilphCo5Script_19f4d: ; 19f4d (6:5f4d)
	ld hl, wd126
	bit 5, [hl]
	res 5, [hl]
	ret z
	ld hl, SilphCo5Coords
	call SilphCo4Script_19d5d
	call SilphCo5Script_19f9e
	ld a, [wd82c]
	bit 0, a
	jr nz, .asm_19f74 ; 0x19f63 $f
	push af
	ld a, $5f
	ld [wd09f], a
	ld bc, $0203
	predef Func_ee9e
	pop af
.asm_19f74
	bit 1, a
	jr nz, .asm_19f87 ; 0x19f76 $f
	push af
	ld a, $5f
	ld [wd09f], a
	ld bc, $0603
	predef Func_ee9e
	pop af
.asm_19f87
	bit 2, a
	ret nz
	ld a, $5f
	ld [wd09f], a
	ld bc, $0507
	predef_jump Func_ee9e

SilphCo5Coords: ; 19f97 (6:5f97) ; coords?
	db $02, $03, $06, $03, $05, $07, $ff

SilphCo5Script_19f9e: ; 19f9e (6:5f9e)
	ld hl, wd82c
	ld a, [$ffe0]
	and a
	ret z
	cp $1
	jr nz, .asm_19fac ; 0x19fa7 $3
	set 0, [hl]
	ret
.asm_19fac
	cp $2
	jr nz, .asm_19fb3 ; 0x19fae $3
	set 1, [hl]
	ret
.asm_19fb3
	set 2, [hl]
	ret

SilphCo5ScriptPointers: ; 19fb6 (6:5fb6)
	dw CheckFightingMapTrainers
	dw Func_324c
	dw EndTrainerBattle

SilphCo5TextPointers: ; 19fbc (6:5fbc)
	dw SilphCo5Text1
	dw SilphCo5Text2
	dw SilphCo5Text3
	dw SilphCo5Text4
	dw SilphCo5Text5
	dw Predef5CText
	dw Predef5CText
	dw Predef5CText
	dw SilphCo5Text9
	dw SilphCo5Text10
	dw SilphCo5Text11

SilphCo5TrainerHeaders: ; 19fd2 (6:5fd2)
Silphco5TrainerHeader0: ; 19fd2 (6:5fd2)
	db $2 ; flag's bit
	db ($1 << 4) ; trainer's view range
	dw wd82b ; flag's byte
	dw SilphCo5BattleText2 ; 0x6024 TextBeforeBattle
	dw SilphCo5AfterBattleText2 ; 0x602e TextAfterBattle
	dw SilphCo5EndBattleText2 ; 0x6029 TextEndBattle
	dw SilphCo5EndBattleText2 ; 0x6029 TextEndBattle

Silphco5TrainerHeader2: ; 19fde (6:5fde)
	db $3 ; flag's bit
	db ($2 << 4) ; trainer's view range
	dw wd82b ; flag's byte
	dw SilphCo5BattleText3 ; 0x603d TextBeforeBattle
	dw SilphCo5AfterBattleText3 ; 0x6047 TextAfterBattle
	dw SilphCo5EndBattleText3 ; 0x6042 TextEndBattle
	dw SilphCo5EndBattleText3 ; 0x6042 TextEndBattle

Silphco5TrainerHeader3: ; 19fea (6:5fea)
	db $4 ; flag's bit
	db ($4 << 4) ; trainer's view range
	dw wd82b ; flag's byte
	dw SilphCo5BattleText4 ; 0x6056 TextBeforeBattle
	dw SilphCo5AfterBattleText4 ; 0x6060 TextAfterBattle
	dw SilphCo5EndBattleText4 ; 0x605b TextEndBattle
	dw SilphCo5EndBattleText4 ; 0x605b TextEndBattle

Silphco5TrainerHeader4: ; 19ff6 (6:5ff6)
	db $5 ; flag's bit
	db ($3 << 4) ; trainer's view range
	dw wd82b ; flag's byte
	dw SilphCo5BattleText5 ; 0x606f TextBeforeBattle
	dw SilphCo5AfterBattleText5 ; 0x6079 TextAfterBattle
	dw SilphCo5EndBattleText5 ; 0x6074 TextEndBattle
	dw SilphCo5EndBattleText5 ; 0x6074 TextEndBattle

	db $ff

SilphCo5Text1: ; 1a003 (6:6003)
	db $08 ; asm
	ld hl, SilphCo5Text_1a010
	ld de, SilphCo5Text_1a015
	call SilphCo6Script_1a22f
	jp TextScriptEnd

SilphCo5Text_1a010: ; 1a010 (6:6010)
	TX_FAR _SilphCo5Text_1a010
	db "@"

SilphCo5Text_1a015: ; 1a015 (6:6015)
	TX_FAR _SilphCo5Text_1a015
	db "@"

SilphCo5Text2: ; 1a01a (6:601a)
	db $08 ; asm
	ld hl, Silphco5TrainerHeader0
	call TalkToTrainer
	jp TextScriptEnd

SilphCo5BattleText2: ; 1a024 (6:6024)
	TX_FAR _SilphCo5BattleText2
	db "@"

SilphCo5EndBattleText2: ; 1a029 (6:6029)
	TX_FAR _SilphCo5EndBattleText2
	db "@"

SilphCo5AfterBattleText2: ; 1a02e (6:602e)
	TX_FAR _SilphCo5AfterBattleText2
	db "@"

SilphCo5Text3: ; 1a033 (6:6033)
	db $08 ; asm
	ld hl, Silphco5TrainerHeader2
	call TalkToTrainer
	jp TextScriptEnd

SilphCo5BattleText3: ; 1a03d (6:603d)
	TX_FAR _SilphCo5BattleText3
	db "@"

SilphCo5EndBattleText3: ; 1a042 (6:6042)
	TX_FAR _SilphCo5EndBattleText3
	db "@"

SilphCo5AfterBattleText3: ; 1a047 (6:6047)
	TX_FAR _SilphCo5AfterBattleText3
	db "@"

SilphCo5Text4: ; 1a04c (6:604c)
	db $08 ; asm
	ld hl, Silphco5TrainerHeader3
	call TalkToTrainer
	jp TextScriptEnd

SilphCo5BattleText4: ; 1a056 (6:6056)
	TX_FAR _SilphCo5BattleText4
	db "@"

SilphCo5EndBattleText4: ; 1a05b (6:605b)
	TX_FAR _SilphCo5EndBattleText4
	db "@"

SilphCo5AfterBattleText4: ; 1a060 (6:6060)
	TX_FAR _SilphCo5AfterBattleText4
	db "@"

SilphCo5Text5: ; 1a065 (6:6065)
	db $08 ; asm
	ld hl, Silphco5TrainerHeader4
	call TalkToTrainer
	jp TextScriptEnd

SilphCo5BattleText5: ; 1a06f (6:606f)
	TX_FAR _SilphCo5BattleText5
	db "@"

SilphCo5EndBattleText5: ; 1a074 (6:6074)
	TX_FAR _SilphCo5EndBattleText5
	db "@"

SilphCo5AfterBattleText5: ; 1a079 (6:6079)
	TX_FAR _SilphCo5AfterBattleText5
	db "@"

SilphCo5Text9: ; 1a07e (6:607e)
	TX_FAR _SilphCo5Text9
	db "@"

SilphCo5Text10: ; 1a083 (6:6083)
	TX_FAR _SilphCo5Text10
	db "@"

SilphCo5Text11: ; 1a088 (6:6088)
	TX_FAR _SilphCo5Text11
	db "@"
