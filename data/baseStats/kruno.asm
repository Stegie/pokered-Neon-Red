KrunoBaseStats: ; 38aa6 (e:4aa6)
db DEX_KRUNO ; pokedex id
db 70 ; base hp
db 120 ; base attack
db 55 ; base defense
db 20 ; base speed
db 150 ; base special
db DARK ; species type 1
db PSYCHIC ; species type 2
db 200 ; catch rate
db 73 ; base exp yield
db $77 ; sprite dimensions
dw KrunoPicFront
dw KrunoPicBack
; attacks known at lvl 0
db CONFUSION
db PSYCHIC
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
db BANK(KrunoPicFront)
