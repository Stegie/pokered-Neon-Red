SSAnne2Object: ; 0x61514 (size=90)
	db $c ; border block

	db $9 ; warps
	db $b, $9, $0, SS_ANNE_9
	db $b, $d, $2, SS_ANNE_9
	db $b, $11, $4, SS_ANNE_9
	db $b, $15, $6, SS_ANNE_9
	db $b, $19, $8, SS_ANNE_9
	db $b, $1d, $a, SS_ANNE_9
	db $4, $2, $8, SS_ANNE_1
	db $c, $2, $1, SS_ANNE_3
	db $4, $24, $0, SS_ANNE_7

	db $0 ; signs

	db $2 ; people
	db SPRITE_WAITER, $7 + 4, $3 + 4, $fe, $1, $1 ; person
	db SPRITE_BLUE, $4 + 4, $24 + 4, $ff, $d0, TRAINER | $2, SONY1 + $C8, $1

	; warp-to
	EVENT_DISP SS_ANNE_2_WIDTH, $b, $9 ; SS_ANNE_9
	EVENT_DISP SS_ANNE_2_WIDTH, $b, $d ; SS_ANNE_9
	EVENT_DISP SS_ANNE_2_WIDTH, $b, $11 ; SS_ANNE_9
	EVENT_DISP SS_ANNE_2_WIDTH, $b, $15 ; SS_ANNE_9
	EVENT_DISP SS_ANNE_2_WIDTH, $b, $19 ; SS_ANNE_9
	EVENT_DISP SS_ANNE_2_WIDTH, $b, $1d ; SS_ANNE_9
	EVENT_DISP SS_ANNE_2_WIDTH, $4, $2 ; SS_ANNE_1
	EVENT_DISP SS_ANNE_2_WIDTH, $c, $2 ; SS_ANNE_3
	EVENT_DISP SS_ANNE_2_WIDTH, $4, $24 ; SS_ANNE_7
