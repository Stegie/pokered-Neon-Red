Route11GateObject: ; 0x49416 (size=50)
	db $a ; border block

	db $5 ; warps
	db $4, $0, $0, $ff
	db $5, $0, $1, $ff
	db $4, $7, $2, $ff
	db $5, $7, $3, $ff
	db $8, $6, $0, ROUTE_11_GATE_2F

	db $0 ; signs

	db $1 ; people
	db SPRITE_GUARD, $1 + 4, $4 + 4, $ff, $ff, $1 ; person

	; warp-to
	EVENT_DISP ROUTE_11_GATE_1F_WIDTH, $4, $0
	EVENT_DISP ROUTE_11_GATE_1F_WIDTH, $5, $0
	EVENT_DISP ROUTE_11_GATE_1F_WIDTH, $4, $7
	EVENT_DISP ROUTE_11_GATE_1F_WIDTH, $5, $7
	EVENT_DISP ROUTE_11_GATE_1F_WIDTH, $8, $6 ; ROUTE_11_GATE_2F
