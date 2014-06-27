EnerguyBaseStats: ; 38aa6 (e:4aa6)
db DEX_ENERGUY ; pokedex id
db 60 ; base hp
db 150 ; base attack
db 50 ; base defense
db 120 ; base speed
db 70 ; base special
db NORMAL ; species type 1
db FLYING ; species type 2
db 200 ; catch rate
db 73 ; base exp yield
db $77 ; sprite dimensions
dw EnerguyPicFront
dw EnerguyPicBack
; attacks known at lvl 0
db GUST
db BARRIER
db MINIMIZE
db DOUBLE_TEAM
db 3 ; growth rate
; learnset
db %10110001
db %00000011
db %00001111
db %11110000
db %10000111
db %00111000
db %01000011
db BANK(EnerguyPicFront)
