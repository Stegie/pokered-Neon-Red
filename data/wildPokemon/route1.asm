Route1Mons:
	db $19
	IF !_YELLOW
		db 4,UMBREON
		db 2,UMBREON
		db 2,BAISEN
		db 3,BAISEN
		db 2,ENERGUY
		db 3,ENERGUY
		db 3,SCIZOR
		db 4,DRAGOR
		db 4,OCEANEEL
		db 5,KRUNO
	ENDC
	IF _YELLOW
		db 4,MACHOP
		db 2,MANKEY
		db 2,MANKEY
		db 3,CATERPIE
		db 2,CATERPIE
		db 3,CATERPIE
		db 3,PIDGEY
		db 4,RATTATA
		db 4,RATTATA
		db 5,PIDGEY
	ENDC
	db $00

