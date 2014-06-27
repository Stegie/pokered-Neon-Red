DragorBaseStats: ; 38aa6 (e:4aa6)
db DEX_DRAGOR ; pokedex id
db 120 ; base hp
db 90 ; base attack
db 70 ; base defense
db 50 ; base speed
db 80 ; base special
db DRAGON ; species type 1
db DRAGON ; species type 2
db 200 ; catch rate
db 73 ; base exp yield
db $77 ; sprite dimensions
dw DRAGORPicFront
dw DRAGORPicBack
; attacks known at lvl 0
db TACKLE
db 0
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
db BANK(DRAGORPicFront)
