BaisenBaseStats: ; 38aa6 (e:4aa6)
db DEX_BAISEN ; pokedex id
db 95 ; base hp
db 130 ; base attack
db 115 ; base defense
db 150 ; base speed
db 95 ; base special
db NORMAL ; species type 1
db NORMAL ; species type 2
db 200 ; catch rate
db 73 ; base exp yield
db $77 ; sprite dimensions
dw BaisenPicFront
dw BaisenPicBack
; attacks known at lvl 0
db SLAM
db STOMP
db TACKLE
db BIDE
db 3 ; growth rate
; learnset
db %10110001
db %00000011
db %00001111
db %11110000
db %10000111
db %00111000
db %01000011
db BANK(BaisenPicFront)
