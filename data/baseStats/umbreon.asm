UmbreonBaseStats: ; 38aa6 (e:4aa6)
db DEX_UMBREON ; pokedex id
db 95 ; base hp
db 65 ; base attack
db 110 ; base defense
db 65 ; base speed
db 95 ; base special
db DARK ; species type 1
db DARK ; species type 2
db 200 ; catch rate
db 73 ; base exp yield
db $77 ; sprite dimensions
dw UmbreonPicFront
dw UmbreonPicBack
; attacks known at lvl 0
db TACKLE
db CONFUSION
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
db BANK(UmbreonPicFront)
