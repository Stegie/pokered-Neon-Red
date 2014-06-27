OceaneelBaseStats: ; 38aa6 (e:4aa6)
db DEX_OCEANEEL ; pokedex id
db 75 ; base hp
db 90 ; base attack
db 70 ; base defense
db 130 ; base speed
db 55 ; base special
db WATER ; species type 1
db ELECTRIC ; species type 2
db 200 ; catch rate
db 73 ; base exp yield
db $77 ; sprite dimensions
dw DRAGORPicFront
dw DRAGORPicBack
; attacks known at lvl 0
db THUNDERSHOCK
db BUBBLE
db 0
db 0
db 3 ; growth rate
; learnset
db %10110001
db %00000011
db %00001111
db %11110000
db %10000111
db %00111000
db %01000011
db BANK(OceaneelPicFront)
