Route16HouseObject: ; 0x1e657 (size=32)
	db $a ; border block

	db $2 ; warps
	db $7, $2, $8, $ff
	db $7, $3, $8, $ff

	db $0 ; signs

	db $2 ; people
	db SPRITE_BRUNETTE_GIRL, $3 + 4, $2 + 4, $ff, $d3, $1 ; person
	db SPRITE_BIRD, $4 + 4, $6 + 4, $fe, $0, $2 ; person

	; warp-to
	EVENT_DISP ROUTE_16_HOUSE_WIDTH, $7, $2
	EVENT_DISP ROUTE_16_HOUSE_WIDTH, $7, $3
