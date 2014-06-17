RocketHideout3Script: ; 45225 (11:5225)
	call EnableAutoTextBoxDrawing
	ld hl, RocketHideout3TrainerHeaders
	ld de, RocketHideout3ScriptPointers
	ld a, [W_ROCKETHIDEOUT3CURSCRIPT]
	call ExecuteCurMapScriptInTable
	ld [W_ROCKETHIDEOUT3CURSCRIPT], a
	ret

RocketHideout3ScriptPointers: ; 45238 (11:5238)
	dw RocketHideout3Script0
	dw Func_324c
	dw EndTrainerBattle
	dw RocketHideout3Script3

RocketHideout3Script0: ; 45240 (11:5240)
	ld a, [W_YCOORD]
	ld b, a
	ld a, [W_XCOORD]
	ld c, a
	ld hl, RocketHideout3ArrowTilePlayerMovement
	call Func_3442
	cp $ff
	jp z, CheckFightingMapTrainers
	ld hl, wd736
	set 7, [hl]
	call Func_3486
	ld a, (SFX_02_52 - SFX_Headers_02) / 3
	call PlaySound
	ld a, $ff
	ld [wJoyIgnore], a
	ld a, $3
	ld [W_CURMAPSCRIPT], a
	ret

;format:
;db y,x
;dw pointer to movement
RocketHideout3ArrowTilePlayerMovement: ; 4526b (11:526b)
	db $d,$a
	dw RocketHideout3ArrowMovement6
	db $13,$a
	dw RocketHideout3ArrowMovement1
	db $12,$b
	dw RocketHideout3ArrowMovement2
	db $b,$c
	dw RocketHideout3ArrowMovement3
	db $11,$c
	dw RocketHideout3ArrowMovement4
	db $14,$c
	dw RocketHideout3ArrowMovement5
	db $10,$d
	dw RocketHideout3ArrowMovement6
	db $b,$e
	dw RocketHideout3ArrowMovement7
	db $f,$e
	dw RocketHideout3ArrowMovement6
	db $11,$e
	dw RocketHideout3ArrowMovement8
	db $13,$e
	dw RocketHideout3ArrowMovement9
	db $10,$f
	dw RocketHideout3ArrowMovement7
	db $12,$f
	dw RocketHideout3ArrowMovement10
	db $d,$10
	dw RocketHideout3ArrowMovement11
	db $c,$11
	dw RocketHideout3ArrowMovement10
	db $10,$12
	dw RocketHideout3ArrowMovement12
	db $FF

;format: direction, count
;right:	$10
;left:	$20
;up:	$40
;down:	$80
;each list is read starting from the $FF and working backwards
RocketHideout3ArrowMovement1: ; 452ac (11:52ac)
	db $10,$04
	db $40,$04
	db $10,$04
	db $FF

RocketHideout3ArrowMovement2: ; 452b3 (11:52b3)
	db $80,$04
	db $10,$04
	db $FF

RocketHideout3ArrowMovement3: ; 452b8 (11:52b8)
	db $20,$02
	db $FF

RocketHideout3ArrowMovement4: ; 452bb (11:52bb)
	db $10,$04
	db $40,$02
	db $10,$02
	db $FF

RocketHideout3ArrowMovement5: ; 452c2 (11:52c2)
	db $10,$04
	db $40,$02
	db $10,$02
	db $40,$03
	db $FF

RocketHideout3ArrowMovement6: ; 452cb (11:52cb)
	db $10,$04
	db $FF

RocketHideout3ArrowMovement7: ; 452ce (11:52ce)
	db $10,$02
	db $FF

RocketHideout3ArrowMovement8: ; 452d1 (11:52d1)
	db $10,$04
	db $40,$02
	db $FF

RocketHideout3ArrowMovement9: ; 452d6 (11:52d6)
	db $10,$04
	db $40,$04
	db $FF

RocketHideout3ArrowMovement10: ; 452db (11:52db)
	db $80,$04
	db $FF

RocketHideout3ArrowMovement11: ; 452de (11:52de)
	db $40,$02
	db $FF

RocketHideout3ArrowMovement12: ; 452e1 (11:52e1)
	db $40,$01
	db $FF

RocketHideout3Script3 ; 452e4 (11:452e4)
	ld a, [wcd38]
	and a
	jp nz, LoadSpinnerArrowTiles
	xor a
	ld [wJoyIgnore], a
	ld hl, wd736
	res 7, [hl]
	ld a, $0
	ld [W_CURMAPSCRIPT], a
	ret

RocketHideout3TextPointers: ; 452fa (11:52fa)
	dw RocketHideout3Text1
	dw RocketHideout3Text2
	dw Predef5CText
	dw Predef5CText

RocketHideout3TrainerHeaders: ; 45302 (11:5302)
RocketHideout3TrainerHeader0: ; 45302 (11:5302)
	db $1 ; flag's bit
	db ($2 << 4) ; trainer's view range
	dw wd819 ; flag's byte
	dw RocketHideout3BattleText2 ; 0x5325 TextBeforeBattle
	dw RocketHideout3AfterBattleTxt2 ; 0x532f TextAfterBattle
	dw RocketHideout3EndBattleText2 ; 0x532a TextEndBattle
	dw RocketHideout3EndBattleText2 ; 0x532a TextEndBattle

RocketHideout3TrainerHeader2: ; 4530e (11:530e)
	db $2 ; flag's bit
	db ($4 << 4) ; trainer's view range
	dw wd819 ; flag's byte
	dw RocketHideout3BattleTxt ; 0x533e TextBeforeBattle
	dw RocketHideout3AfterBattleText3 ; 0x5348 TextAfterBattle
	dw RocketHideout3EndBattleText3 ; 0x5343 TextEndBattle
	dw RocketHideout3EndBattleText3 ; 0x5343 TextEndBattle

	db $ff

RocketHideout3Text1: ; 4531b (11:531b)
	db $08 ; asm
	ld hl, RocketHideout3TrainerHeader0
	call TalkToTrainer
	jp TextScriptEnd

RocketHideout3BattleText2: ; 45325 (11:5325)
	TX_FAR _RocketHideout3BattleText2
	db "@"

RocketHideout3EndBattleText2: ; 4532a (11:532a)
	TX_FAR _RocketHideout3EndBattleText2
	db "@"

RocketHideout3AfterBattleTxt2: ; 4532f (11:532f)
	TX_FAR _RocketHideout3AfterBattleTxt2
	db "@"

RocketHideout3Text2: ; 45334 (11:5334)
	db $08 ; asm
	ld hl, RocketHideout3TrainerHeader2
	call TalkToTrainer
	jp TextScriptEnd

RocketHideout3BattleTxt: ; 4533e (11:533e)
	TX_FAR _RocketHideout3BattleTxt
	db "@"

RocketHideout3EndBattleText3: ; 45343 (11:5343)
	TX_FAR _RocketHideout3EndBattleText3
	db "@"

RocketHideout3AfterBattleText3: ; 45348 (11:5348)
	TX_FAR _RocketHide3AfterBattleText3
	db "@"
