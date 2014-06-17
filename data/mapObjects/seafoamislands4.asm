SeafoamIslands4Object: ; 0x466a6 (size=96)
	db $7d ; border block

	db $7 ; warps
	db $c, $5, $1, SEAFOAM_ISLANDS_3
	db $6, $8, $2, SEAFOAM_ISLANDS_5
	db $4, $19, $3, SEAFOAM_ISLANDS_5
	db $3, $19, $4, SEAFOAM_ISLANDS_3
	db $e, $19, $6, SEAFOAM_ISLANDS_3
	db $11, $14, $0, SEAFOAM_ISLANDS_5
	db $11, $15, $1, SEAFOAM_ISLANDS_5

	db $0 ; signs

	db $6 ; people
	db SPRITE_BOULDER, $e + 4, $5 + 4, $ff, $10, $1 ; person
	db SPRITE_BOULDER, $f + 4, $3 + 4, $ff, $10, $2 ; person
	db SPRITE_BOULDER, $e + 4, $8 + 4, $ff, $10, $3 ; person
	db SPRITE_BOULDER, $e + 4, $9 + 4, $ff, $10, $4 ; person
	db SPRITE_BOULDER, $6 + 4, $12 + 4, $ff, $ff, $5 ; person
	db SPRITE_BOULDER, $6 + 4, $13 + 4, $ff, $ff, $6 ; person

	; warp-to
	EVENT_DISP SEAFOAM_ISLANDS_4_WIDTH, $c, $5 ; SEAFOAM_ISLANDS_3
	EVENT_DISP SEAFOAM_ISLANDS_4_WIDTH, $6, $8 ; SEAFOAM_ISLANDS_5
	EVENT_DISP SEAFOAM_ISLANDS_4_WIDTH, $4, $19 ; SEAFOAM_ISLANDS_5
	EVENT_DISP SEAFOAM_ISLANDS_4_WIDTH, $3, $19 ; SEAFOAM_ISLANDS_3
	EVENT_DISP SEAFOAM_ISLANDS_4_WIDTH, $e, $19 ; SEAFOAM_ISLANDS_3
	EVENT_DISP SEAFOAM_ISLANDS_4_WIDTH, $11, $14 ; SEAFOAM_ISLANDS_5
	EVENT_DISP SEAFOAM_ISLANDS_4_WIDTH, $11, $15 ; SEAFOAM_ISLANDS_5
