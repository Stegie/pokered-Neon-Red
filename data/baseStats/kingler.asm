KinglerBaseStats: ; 38e96 (e:4e96)
db DEX_KINGLER ; pokedex id
db 55 ; base hp
db 130 ; base attack
db 115 ; base defense
db 75 ; base speed
db 50 ; base special
db WATER ; species type 1
db WATER ; species type 2
db 60 ; catch rate
db 206 ; base exp yield
db $77 ; sprite dimensions
dw KinglerPicFront
dw KinglerPicBack
; attacks known at lvl 0
db BUBBLE
db LEER
db VICEGRIP
db 0
db 0 ; growth rate
; learnset
db %10100100
db %01111111
db %00001000
db %11000000
db %00000010
db %00001000
db %00110110
db BANK(KinglerPicFront)