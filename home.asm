; The rst vectors are unused.
SECTION "rst00", ROM0[$00]
	rst $38
SECTION "rst08", ROM0[$08]
	rst $38
SECTION "rst10", ROM0[$10]
	rst $38
SECTION "rst18", ROM0[$18]
	rst $38
SECTION "rst20", ROM0[$20]
	rst $38
SECTION "rst28", ROM0[$28]
	rst $38
SECTION "rst30", ROM0[$30]
	rst $38
SECTION "rst38", ROM0[$38]
	rst $38

; interrupts
SECTION "vblank", ROM0[$40]
	jp VBlank
SECTION "lcdc",   ROM0[$48]
	rst $38
SECTION "timer",  ROM0[$50]
	jp Timer
SECTION "serial", ROM0[$58]
	jp Serial
SECTION "joypad", ROM0[$60]
	reti


SECTION "bank0",ROM0[$61]

DisableLCD::
	xor a
	ld [rIF], a
	ld a, [rIE]
	ld b, a
	res 0, a
	ld [rIE], a

.wait
	ld a, [rLY]
	cp LY_VBLANK
	jr nz, .wait

	ld a, [rLCDC]
	and $ff ^ rLCDC_ENABLE_MASK
	ld [rLCDC], a
	ld a, b
	ld [rIE], a
	ret

EnableLCD::
	ld a, [rLCDC]
	set rLCDC_ENABLE, a
	ld [rLCDC], a
	ret

ClearSprites::
	xor a
	ld hl, wOAMBuffer
	ld b, 40 * 4
.loop
	ld [hli], a
	dec b
	jr nz, .loop
	ret

HideSprites::
	ld a, 160
	ld hl, wOAMBuffer
	ld de, 4
	ld b, 40
.loop
	ld [hl], a
	add hl, de
	dec b
	jr nz, .loop
	ret

FarCopyData::
; Copy bc bytes from a:hl to de.
	ld [wBuffer], a
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, [wBuffer]
	ld [H_LOADEDROMBANK], a
	ld [MBC3RomBank], a
	call CopyData
	pop af
	ld [H_LOADEDROMBANK], a
	ld [MBC3RomBank], a
	ret

CopyData::
; Copy bc bytes from hl to de.
	ld a, [hli]
	ld [de], a
	inc de
	dec bc
	ld a, c
	or b
	jr nz, CopyData
	ret


SECTION "Entry", ROM0[$100]
	nop
	jp Start


SECTION "Start", ROM0[$150]

Start::
	cp GBC
	jr z, .gbc
	xor a
	jr .ok
.gbc
	ld a, 0
.ok
	ld [wGBC], a
	jp Init


INCLUDE "home/joypad.asm"

INCLUDE "data/map_header_pointers.asm"

INCLUDE "home/overworld.asm"

; this is used to check if the player wants to interrupt the opening sequence at several points
; XXX is this used anywhere else?
; INPUT:
; c = number of frames to wait
; sets carry if Up+Select+B, Start, or A is pressed within c frames
; unsets carry otherwise
CheckForUserInterruption:: ; 12f8 (0:12f8)
	call DelayFrame
	push bc
	call JoypadLowSensitivity
	pop bc
	ld a,[hJoyHeld] ; currently pressed buttons
	cp a,%01000110 ; Up, Select button, B button
	jr z,.setCarry ; if all three keys are pressed
	ld a,[$ffb5] ; either newly pressed buttons or currently pressed buttons at low sampling rate
	and a,%00001001 ; Start button, A button
	jr nz,.setCarry ; if either key is pressed
	dec c
	jr nz,CheckForUserInterruption
.unsetCarry
	and a
	ret
.setCarry
	scf
	ret

; function to load position data for destination warp when switching maps
; INPUT:
; a = ID of destination warp within destination map
LoadDestinationWarpPosition:: ; 1313 (0:1313)
	ld b,a
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,[wPredefParentBank]
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ld a,b
	add a
	add a
	ld c,a
	ld b,0
	add hl,bc
	ld bc,4
	ld de,wd35f
	call CopyData
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; INPUT:
; c: if nonzero, show at least a sliver of health
; d = number of HP bar sections (normally 6)
; e = health (in eighths of bar sections) (normally out of 48)
DrawHPBar:: ; 1336 (0:1336)
	push hl
	push de
	push bc
	ld a,$71 ; left of HP bar tile 1
	ld [hli],a
	ld a,$62 ; left of HP bar tile 2
	ld [hli],a
	push hl
	ld a,$63 ; empty bar section tile
.drawEmptyBarLoop
	ld [hli],a
	dec d
	jr nz,.drawEmptyBarLoop
	ld a,[wListMenuID]
	dec a ; what should the right of HP bar tile be?
	ld a,$6d ; right of HP bar tile, in status screen and battles
	jr z,.writeTile
	dec a ; right of HP bar tile, in pokemon menu
.writeTile
	ld [hl],a
	pop hl
	ld a,e
	and a ; is there enough health to show up on the HP bar?
	jr nz,.loop ; if so, draw the HP bar
	ld a,c
	and a ; should a sliver of health be shown no matter what?
	jr z,.done
	ld e,1 ; if so, fill one eighth of a bar section
; loop to draw every full bar section
.loop
	ld a,e
	sub a,8
	jr c,.drawPartialBarSection
	ld e,a
	ld a,$6b ; filled bar section tile
	ld [hli],a
	ld a,e
	and a
	jr z,.done
	jr .loop
; draws a partial bar section at the end (if necessary)
; there are 7 possible partial bar sections from 1/8 to 7/8 full
.drawPartialBarSection
	ld a,$63 ; empty bar section tile
	add e ; add e to get the appropriate partial bar section tile
	ld [hl],a ; write the tile
.done
	pop bc
	pop de
	pop hl
	ret

; loads pokemon data from one of multiple sources to wcf98
; loads base stats to W_MONHDEXNUM
; INPUT:
; [wWhichPokemon] = index of pokemon within party/box
; [wcc49] = source
; 00: player's party
; 01: enemy's party
; 02: current box
; 03: daycare
; OUTPUT:
; [wcf91] = pokemon ID
; wcf98 = base address of pokemon data
; W_MONHDEXNUM = base address of base stats
LoadMonData:: ; 1372 (0:1372)
	ld hl,LoadMonData_
	ld b,BANK(LoadMonData_)
	jp Bankswitch

; writes c to wd0dc+b
Func_137a:: ; 137a (0:137a)
	ld hl, wd0dc
	ld e, b
	ld d, $0
	add hl, de
	ld a, c
	ld [hl], a
	ret

LoadFlippedFrontSpriteByMonIndex:: ; 1384 (0:1384)
	ld a, $1
	ld [W_SPRITEFLIPPED], a

LoadFrontSpriteByMonIndex:: ; 1389 (0:1389)
	push hl
	ld a, [wd11e]
	push af
	ld a, [wcf91]
	ld [wd11e], a
	predef IndexToPokedex
	ld hl, wd11e
	ld a, [hl]
	pop bc
	ld [hl], b
	and a
	pop hl
	jr z, .invalidDexNumber  ; dex #0 invalid
	cp NUM_POKEMON + 1
	jr c, .validDexNumber    ; dex >#151 invalid
.invalidDexNumber
	ld a, RHYDON ; $1
	ld [wcf91], a
	ret
.validDexNumber
	push hl
	ld de, vFrontPic
	call LoadMonFrontSprite
	pop hl
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, Bank(asm_3f0d0)
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	xor a
	ld [$ffe1], a
	call asm_3f0d0
	xor a
	ld [W_SPRITEFLIPPED], a
	pop af
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ret

; plays the cry of a pokemon
; INPUT:
; a = pokemon ID
PlayCry:: ; 13d0 (0:13d0)
	call GetCryData
	call PlaySound ; play cry
	jp WaitForSoundToFinish ; wait for sound to be done playing

; gets a pokemon's cry data
; INPUT:
; a = pokemon ID
GetCryData:: ; 13d9 (0:13d9)
	dec a
	ld c,a
	ld b,0
	ld hl,CryData
	add hl,bc
	add hl,bc
	add hl,bc
	ld a,Bank(CryData)
	call BankswitchHome
	ld a,[hli]
	ld b,a
	ld a,[hli]
	ld [wc0f1],a
	ld a,[hl]
	ld [wc0f2],a
	call BankswitchBack
	ld a,b ; a = cryID
	ld c,$14 ; base sound ID for pokemon cries
	rlca
	add b ; a = cryID * 3
	add c ; a = $14 + cryID * 3
	ret

DisplayPartyMenu:: ; 13fc (0:13fc)
	ld a,[$ffd7]
	push af
	xor a
	ld [$ffd7],a
	call GBPalWhiteOutWithDelay3
	call ClearSprites
	call PartyMenuInit
	call DrawPartyMenu
	jp HandlePartyMenuInput

GoBackToPartyMenu:: ; 1411 (0:1411)
	ld a,[$ffd7]
	push af
	xor a
	ld [$ffd7],a
	call PartyMenuInit
	call RedrawPartyMenu
	jp HandlePartyMenuInput

PartyMenuInit:: ; 1420 (0:1420)
	ld a,$01
	call BankswitchHome
	call LoadHpBarAndStatusTilePatterns
	ld hl,wd730
	set 6,[hl] ; turn off letter printing delay
	xor a
	ld [wcc49],a
	ld [wcc37],a
	ld hl,wTopMenuItemY
	inc a
	ld [hli],a ; top menu item Y
	xor a
	ld [hli],a ; top menu item X
	ld a,[wcc2b]
	push af
	ld [hli],a ; current menu item ID
	inc hl
	ld a,[wPartyCount]
	and a ; are there more than 0 pokemon in the party?
	jr z,.storeMaxMenuItemID
	dec a
; if party is not empty, the max menu item ID is ([wPartyCount] - 1)
; otherwise, it is 0
.storeMaxMenuItemID
	ld [hli],a ; max menu item ID
	ld a,[wd11f]
	and a
	ld a,%00000011 ; A button and B button
	jr z,.next
	xor a
	ld [wd11f],a
	inc a
.next
	ld [hli],a ; menu watched keys
	pop af
	ld [hl],a ; old menu item ID
	ret

HandlePartyMenuInput:: ; 145a (0:145a)
	ld a,1
	ld [wMenuWrappingEnabled],a
	ld a,$40
	ld [wd09b],a
	call HandleMenuInputPokemonSelection
	call PlaceUnfilledArrowMenuCursor
	ld b,a
	xor a
	ld [wd09b],a
	ld a,[wCurrentMenuItem]
	ld [wcc2b],a
	ld hl,wd730
	res 6,[hl] ; turn on letter printing delay
	ld a,[wcc35]
	and a
	jp nz,.swappingPokemon
	pop af
	ld [$ffd7],a
	bit 1,b
	jr nz,.noPokemonChosen
	ld a,[wPartyCount]
	and a
	jr z,.noPokemonChosen
	ld a,[wCurrentMenuItem]
	ld [wWhichPokemon],a
	ld hl,wPartySpecies
	ld b,0
	ld c,a
	add hl,bc
	ld a,[hl]
	ld [wcf91],a
	ld [wBattleMonSpecies2],a
	call BankswitchBack
	and a
	ret
.noPokemonChosen
	call BankswitchBack
	scf
	ret
.swappingPokemon
	bit 1,b ; was the B button pressed?
	jr z,.handleSwap ; if not, handle swapping the pokemon
.cancelSwap ; if the B button was pressed
	callba ErasePartyMenuCursors
	xor a
	ld [wcc35],a
	ld [wd07d],a
	call RedrawPartyMenu
	jr HandlePartyMenuInput
.handleSwap
	ld a,[wCurrentMenuItem]
	ld [wWhichPokemon],a
	callba SwitchPartyMon
	jr HandlePartyMenuInput

DrawPartyMenu:: ; 14d4 (0:14d4)
	ld hl, DrawPartyMenu_
	jr DrawPartyMenuCommon

RedrawPartyMenu:: ; 14d9 (0:14d9)
	ld hl, RedrawPartyMenu_

DrawPartyMenuCommon:: ; 14dc (0:14dc)
	ld b, BANK(RedrawPartyMenu_)
	jp Bankswitch

; prints a pokemon's status condition
; INPUT:
; de = address of status condition
; hl = destination address
PrintStatusCondition:: ; 14e1 (0:14e1)
	push de
	dec de
	dec de ; de = address of current HP
	ld a,[de]
	ld b,a
	dec de
	ld a,[de]
	or b ; is the pokemon's HP zero?
	pop de
	jr nz,PrintStatusConditionNotFainted
; if the pokemon's HP is 0, print "FNT"
	ld a,"F"
	ld [hli],a
	ld a,"N"
	ld [hli],a
	ld [hl],"T"
	and a
	ret
PrintStatusConditionNotFainted ; 14f6
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,BANK(PrintStatusAilment)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call PrintStatusAilment ; print status condition
	pop bc
	ld a,b
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; function to print pokemon level, leaving off the ":L" if the level is at least 100
; INPUT:
; hl = destination address
; [wcfb9] = level
PrintLevel:: ; 150b (0:150b)
	ld a,$6e ; ":L" tile ID
	ld [hli],a
	ld c,2 ; number of digits
	ld a,[wcfb9] ; level
	cp a,100
	jr c,PrintLevelCommon
; if level at least 100, write over the ":L" tile
	dec hl
	inc c ; increment number of digits to 3
	jr PrintLevelCommon

; prints the level without leaving off ":L" regardless of level
; INPUT:
; hl = destination address
; [wcfb9] = level
PrintLevelFull:: ; 151b (0:151b)
	ld a,$6e ; ":L" tile ID
	ld [hli],a
	ld c,3 ; number of digits
	ld a,[wcfb9] ; level

PrintLevelCommon:: ; 1523 (0:1523)
	ld [wd11e],a
	ld de,wd11e
	ld b,$41 ; no leading zeroes, left-aligned, one byte
	jp PrintNumber

Func_152e:: ; 152e (0:152e)
	ld hl,wd0dc
	ld c,a
	ld b,0
	add hl,bc
	ld a,[hl]
	ret

; copies the base stat data of a pokemon to W_MONHDEXNUM (W_MONHEADER)
; INPUT:
; [wd0b5] = pokemon ID
GetMonHeader:: ; 1537 (0:1537)
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,BANK(BaseStats)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	push bc
	push de
	push hl
	ld a,[wd11e]
	push af
	ld a,[wd0b5]
	ld [wd11e],a
	ld de,FossilKabutopsPic
	ld b,$66 ; size of Kabutops fossil and Ghost sprites
	cp a,FOSSIL_KABUTOPS ; Kabutops fossil
	jr z,.specialID
	ld de,GhostPic
	cp a,MON_GHOST ; Ghost
	jr z,.specialID
	ld de,FossilAerodactylPic
	ld b,$77 ; size of Aerodactyl fossil sprite
	cp a,FOSSIL_AERODACTYL ; Aerodactyl fossil
	jr z,.specialID
	cp a,MEW
	jr z,.mew
	predef IndexToPokedex   ; convert pokemon ID in [wd11e] to pokedex number
	ld a,[wd11e]
	dec a
	ld bc,28
	ld hl,BaseStats
	call AddNTimes
	ld de,W_MONHEADER
	ld bc,28
	call CopyData
	jr .done
.specialID
	ld hl,W_MONHSPRITEDIM
	ld [hl],b ; write sprite dimensions
	inc hl
	ld [hl],e ; write front sprite pointer
	inc hl
	ld [hl],d
	jr .done
.mew
	ld hl,MewBaseStats
	ld de,W_MONHEADER
	ld bc,28
	ld a,BANK(MewBaseStats)
	call FarCopyData
.done
	ld a,[wd0b5]
	ld [W_MONHDEXNUM],a
	pop af
	ld [wd11e],a
	pop hl
	pop de
	pop bc
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; copy party pokemon's name to wcd6d
GetPartyMonName2:: ; 15b4 (0:15b4)
	ld a,[wWhichPokemon] ; index within party
	ld hl,wPartyMonNicks

; this is called more often
GetPartyMonName:: ; 15ba (0:15ba)
	push hl
	push bc
	call SkipFixedLengthTextEntries ; add 11 to hl, a times
	ld de,wcd6d
	push de
	ld bc,11
	call CopyData
	pop de
	pop bc
	pop hl
	ret

; function to print a BCD (Binary-coded decimal) number
; de = address of BCD number
; hl = destination address
; c = flags and length
; bit 7: if set, do not print leading zeroes
;        if unset, print leading zeroes
; bit 6: if set, left-align the string (do not pad empty digits with spaces)
;        if unset, right-align the string
; bit 5: if set, print currency symbol at the beginning of the string
;        if unset, do not print the currency symbol
; bits 0-4: length of BCD number in bytes
; Note that bits 5 and 7 are modified during execution. The above reflects
; their meaning at the beginning of the functions's execution.
PrintBCDNumber:: ; 15cd (0:15cd)
	ld b,c ; save flags in b
	res 7,c
	res 6,c
	res 5,c ; c now holds the length
	bit 5,b
	jr z,.loop
	bit 7,b
	jr nz,.loop
	ld [hl],"¥"
	inc hl
.loop
	ld a,[de]
	swap a
	call PrintBCDDigit ; print upper digit
	ld a,[de]
	call PrintBCDDigit ; print lower digit
	inc de
	dec c
	jr nz,.loop
	bit 7,b ; were any non-zero digits printed?
	jr z,.done ; if so, we are done
.numberEqualsZero ; if every digit of the BCD number is zero
	bit 6,b ; left or right alignment?
	jr nz,.skipRightAlignmentAdjustment
	dec hl ; if the string is right-aligned, it needs to be moved back one space
.skipRightAlignmentAdjustment
	bit 5,b
	jr z,.skipCurrencySymbol
	ld [hl],"¥"
	inc hl
.skipCurrencySymbol
	ld [hl],"0"
	call PrintLetterDelay
	inc hl
.done
	ret

PrintBCDDigit:: ; 1604 (0:1604)
	and a,%00001111
	and a
	jr z,.zeroDigit
.nonzeroDigit
	bit 7,b ; have any non-space characters been printed?
	jr z,.outputDigit
; if bit 7 is set, then no numbers have been printed yet
	bit 5,b ; print the currency symbol?
	jr z,.skipCurrencySymbol
	ld [hl],"¥"
	inc hl
	res 5,b
.skipCurrencySymbol
	res 7,b ; unset 7 to indicate that a nonzero digit has been reached
.outputDigit
	add a,"0"
	ld [hli],a
	jp PrintLetterDelay
.zeroDigit
	bit 7,b ; either printing leading zeroes or already reached a nonzero digit?
	jr z,.outputDigit ; if so, print a zero digit
	bit 6,b ; left or right alignment?
	ret nz
	inc hl ; if right-aligned, "print" a space by advancing the pointer
	ret

; uncompresses the front or back sprite of the specified mon
; assumes the corresponding mon header is already loaded
; hl contains offset to sprite pointer ($b for front or $d for back)
UncompressMonSprite:: ; 1627 (0:1627)
	ld bc,W_MONHEADER
	add hl,bc
	ld a,[hli]
	ld [W_SPRITEINPUTPTR],a    ; fetch sprite input pointer
	ld a,[hl]
	ld [W_SPRITEINPUTPTR+1],a
; define (by index number) the bank that a pokemon's image is in
; index = Mew, bank 1
; index = Kabutops fossil, bank $B
;	index < $1F, bank 9
; $1F ≤ index < $4A, bank $A
; $4A ≤ index < $74, bank $B
; $74 ≤ index < $99, bank $C
; $99 ≤ index,       bank $D
	ld a,[wcf91] ; XXX name for this ram location
	ld b,a
	cp MEW
	ld a,BANK(MewPicFront)
	jr z,.GotBank
	ld a,b
	cp FOSSIL_KABUTOPS
	ld a,BANK(FossilKabutopsPic)
	jr z,.GotBank
	ld a,b
	cp TANGELA + 1
	ld a,BANK(TangelaPicFront)
	jr c,.GotBank
	ld a,b
	cp MOLTRES + 1
	ld a,BANK(MoltresPicFront)
	jr c,.GotBank
	ld a,b
	cp BEEDRILL + 2
	ld a,BANK(BeedrillPicFront)
	jr c,.GotBank
	ld a,b
	cp STARMIE + 1
	ld a,BANK(StarmiePicFront)
	jr c,.GotBank
	ld a,BANK(VictreebelPicFront)
.GotBank
	jp UncompressSpriteData

; de: destination location
LoadMonFrontSprite:: ; 1665 (0:1665)
	push de
	ld hl, W_MONHFRONTSPRITE - W_MONHEADER
	call UncompressMonSprite
	ld hl, W_MONHSPRITEDIM
	ld a, [hli]
	ld c, a
	pop de
	; fall through

; postprocesses uncompressed sprite chunks to a 2bpp sprite and loads it into video ram
; calculates alignment parameters to place both sprite chunks in the center of the 7*7 tile sprite buffers
; de: destination location
; a,c:  sprite dimensions (in tiles of 8x8 each)
LoadUncompressedSpriteData:: ; 1672 (0:1672)
	push de
	and $f
	ld [H_SPRITEWIDTH], a ; each byte contains 8 pixels (in 1bpp), so tiles=bytes for width
	ld b, a
	ld a, $7
	sub b      ; 7-w
	inc a      ; 8-w
	srl a      ; (8-w)/2     ; horizontal center (in tiles, rounded up)
	ld b, a
	add a
	add a
	add a
	sub b      ; 7*((8-w)/2) ; skip for horizontal center (in tiles)
	ld [H_SPRITEOFFSET], a
	ld a, c
	swap a
	and $f
	ld b, a
	add a
	add a
	add a     ; 8*tiles is height in bytes
	ld [H_SPRITEHEIGHT], a ; $ff8c
	ld a, $7
	sub b      ; 7-h         ; skip for vertical center (in tiles, relative to current column)
	ld b, a
	ld a, [H_SPRITEOFFSET]
	add b     ; 7*((8-w)/2) + 7-h ; combined overall offset (in tiles)
	add a
	add a
	add a     ; 8*(7*((8-w)/2) + 7-h) ; combined overall offset (in bytes)
	ld [H_SPRITEOFFSET], a
	xor a
	ld [$4000], a
	ld hl, S_SPRITEBUFFER0
	call ZeroSpriteBuffer   ; zero buffer 0
	ld de, S_SPRITEBUFFER1
	ld hl, S_SPRITEBUFFER0
	call AlignSpriteDataCentered    ; copy and align buffer 1 to 0 (containing the MSB of the 2bpp sprite)
	ld hl, S_SPRITEBUFFER1
	call ZeroSpriteBuffer   ; zero buffer 1
	ld de, S_SPRITEBUFFER2
	ld hl, S_SPRITEBUFFER1
	call AlignSpriteDataCentered    ; copy and align buffer 2 to 1 (containing the LSB of the 2bpp sprite)
	pop de
	jp InterlaceMergeSpriteBuffers

; copies and aligns the sprite data properly inside the sprite buffer
; sprite buffers are 7*7 tiles in size, the loaded sprite is centered within this area
AlignSpriteDataCentered:: ; 16c2 (0:16c2)
	ld a, [H_SPRITEOFFSET]
	ld b, $0
	ld c, a
	add hl, bc
	ld a, [H_SPRITEWIDTH] ; $ff8b
.columnLoop
	push af
	push hl
	ld a, [H_SPRITEHEIGHT] ; $ff8c
	ld c, a
.columnInnerLoop
	ld a, [de]
	inc de
	ld [hli], a
	dec c
	jr nz, .columnInnerLoop
	pop hl
	ld bc, 7*8    ; 7 tiles
	add hl, bc    ; advance one full column
	pop af
	dec a
	jr nz, .columnLoop
	ret

; fills the sprite buffer (pointed to in hl) with zeros
ZeroSpriteBuffer:: ; 16df (0:16df)
	ld bc, SPRITEBUFFERSIZE
.nextByteLoop
	xor a
	ld [hli], a
	dec bc
	ld a, b
	or c
	jr nz, .nextByteLoop
	ret

; combines the (7*7 tiles, 1bpp) sprite chunks in buffer 0 and 1 into a 2bpp sprite located in buffer 1 through 2
; in the resulting sprite, the rows of the two source sprites are interlaced
; de: output address
InterlaceMergeSpriteBuffers:: ; 16ea (0:16ea)
	xor a
	ld [$4000], a
	push de
	ld hl, S_SPRITEBUFFER2 + (SPRITEBUFFERSIZE - 1) ; destination: end of buffer 2
	ld de, S_SPRITEBUFFER1 + (SPRITEBUFFERSIZE - 1) ; source 2: end of buffer 1
	ld bc, S_SPRITEBUFFER0 + (SPRITEBUFFERSIZE - 1) ; source 1: end of buffer 0
	ld a, SPRITEBUFFERSIZE/2 ; $c4
	ld [H_SPRITEINTERLACECOUNTER], a ; $ff8b
.interlaceLoop
	ld a, [de]
	dec de
	ld [hld], a   ; write byte of source 2
	ld a, [bc]
	dec bc
	ld [hld], a   ; write byte of source 1
	ld a, [de]
	dec de
	ld [hld], a   ; write byte of source 2
	ld a, [bc]
	dec bc
	ld [hld], a   ; write byte of source 1
	ld a, [H_SPRITEINTERLACECOUNTER] ; $ff8b
	dec a
	ld [H_SPRITEINTERLACECOUNTER], a ; $ff8b
	jr nz, .interlaceLoop
	ld a, [W_SPRITEFLIPPED]
	and a
	jr z, .notFlipped
	ld bc, 2*SPRITEBUFFERSIZE
	ld hl, S_SPRITEBUFFER1
.swapLoop
	swap [hl]    ; if flipped swap nybbles in all bytes
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .swapLoop
.notFlipped
	pop hl
	ld de, S_SPRITEBUFFER1
	ld c, (2*SPRITEBUFFERSIZE)/16 ; $31, number of 16 byte chunks to be copied
	ld a, [H_LOADEDROMBANK]
	ld b, a
	jp CopyVideoData


INCLUDE "data/collision.asm"


FarCopyData2::
; Identical to FarCopyData, but uses $ff8b
; as temp space instead of wBuffer.
	ld [$ff8b],a
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,[$ff8b]
	ld [H_LOADEDROMBANK],a
	ld [MBC3RomBank],a
	call CopyData
	pop af
	ld [H_LOADEDROMBANK],a
	ld [MBC3RomBank],a
	ret

FarCopyData3::
; Copy bc bytes from a:de to hl.
	ld [$ff8b],a
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,[$ff8b]
	ld [H_LOADEDROMBANK],a
	ld [MBC3RomBank],a
	push hl
	push de
	push de
	ld d,h
	ld e,l
	pop hl
	call CopyData
	pop de
	pop hl
	pop af
	ld [H_LOADEDROMBANK],a
	ld [MBC3RomBank],a
	ret

FarCopyDataDouble::
; Expand bc bytes of 1bpp image data
; from a:hl to 2bpp data at de.
	ld [$ff8b],a
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,[$ff8b]
	ld [H_LOADEDROMBANK],a
	ld [MBC3RomBank],a
.loop
	ld a,[hli]
	ld [de],a
	inc de
	ld [de],a
	inc de
	dec bc
	ld a,c
	or b
	jr nz,.loop
	pop af
	ld [H_LOADEDROMBANK],a
	ld [MBC3RomBank],a
	ret

CopyVideoData::
; Wait for the next VBlank, then copy c 2bpp
; tiles from b:de to hl, 8 tiles at a time.
; This takes c/8 frames.

	ld a, [H_AUTOBGTRANSFERENABLED]
	push af
	xor a ; disable auto-transfer while copying
	ld [H_AUTOBGTRANSFERENABLED], a

	ld a, [H_LOADEDROMBANK]
	ld [$ff8b], a

	ld a, b
	ld [H_LOADEDROMBANK], a
	ld [MBC3RomBank], a

	ld a, e
	ld [H_VBCOPYSRC], a
	ld a, d
	ld [H_VBCOPYSRC + 1], a

	ld a, l
	ld [H_VBCOPYDEST], a
	ld a, h
	ld [H_VBCOPYDEST + 1], a

.loop
	ld a, c
	cp 8
	jr nc, .keepgoing

.done
	ld [H_VBCOPYSIZE], a
	call DelayFrame
	ld a, [$ff8b]
	ld [H_LOADEDROMBANK], a
	ld [MBC3RomBank], a
	pop af
	ld [H_AUTOBGTRANSFERENABLED], a
	ret

.keepgoing
	ld a, 8
	ld [H_VBCOPYSIZE], a
	call DelayFrame
	ld a, c
	sub 8
	ld c, a
	jr .loop

CopyVideoDataDouble::
; Wait for the next VBlank, then copy c 1bpp
; tiles from b:de to hl, 8 tiles at a time.
; This takes c/8 frames.
	ld a, [H_AUTOBGTRANSFERENABLED]
	push af
	xor a ; disable auto-transfer while copying
	ld [H_AUTOBGTRANSFERENABLED], a
	ld a, [H_LOADEDROMBANK]
	ld [$ff8b], a

	ld a, b
	ld [H_LOADEDROMBANK], a
	ld [MBC3RomBank], a

	ld a, e
	ld [H_VBCOPYDOUBLESRC], a
	ld a, d
	ld [H_VBCOPYDOUBLESRC + 1], a

	ld a, l
	ld [H_VBCOPYDOUBLEDEST], a
	ld a, h
	ld [H_VBCOPYDOUBLEDEST + 1], a

.loop
	ld a, c
	cp 8
	jr nc, .keepgoing

.done
	ld [H_VBCOPYDOUBLESIZE], a
	call DelayFrame
	ld a, [$ff8b]
	ld [H_LOADEDROMBANK], a
	ld [MBC3RomBank], a
	pop af
	ld [H_AUTOBGTRANSFERENABLED], a
	ret

.keepgoing
	ld a, 8
	ld [H_VBCOPYDOUBLESIZE], a
	call DelayFrame
	ld a, c
	sub 8
	ld c, a
	jr .loop

ClearScreenArea::
; Clear tilemap area cxb at hl.
	ld a, $7f ; blank tile
	ld de, 20 ; screen width
.y
	push hl
	push bc
.x
	ld [hli], a
	dec c
	jr nz, .x
	pop bc
	pop hl
	add hl, de
	dec b
	jr nz, .y
	ret

CopyScreenTileBufferToVRAM::
; Copy wTileMap to the BG Map starting at b * $100.
; This is done in thirds of 6 rows, so it takes 3 frames.

	ld c, 6

	ld hl, $600 * 0
	ld de, wTileMap + 20 * 6 * 0
	call .setup
	call DelayFrame

	ld hl, $600 * 1
	ld de, wTileMap + 20 * 6 * 1
	call .setup
	call DelayFrame

	ld hl, $600 * 2
	ld de, wTileMap + 20 * 6 * 2
	call .setup
	jp DelayFrame

.setup
	ld a, d
	ld [H_VBCOPYBGSRC+1], a
	call GetRowColAddressBgMap
	ld a, l
	ld [H_VBCOPYBGDEST], a
	ld a, h
	ld [H_VBCOPYBGDEST+1], a
	ld a, c
	ld [H_VBCOPYBGNUMROWS], a
	ld a, e
	ld [H_VBCOPYBGSRC], a
	ret

ClearScreen::
; Clear wTileMap, then wait
; for the bg map to update.
	ld bc, 20 * 18
	inc b
	ld hl, wTileMap
	ld a, $7f
.loop
	ld [hli], a
	dec c
	jr nz, .loop
	dec b
	jr nz, .loop
	jp Delay3


INCLUDE "home/text.asm"
INCLUDE "home/vcopy.asm"
INCLUDE "home/init.asm"
INCLUDE "home/vblank.asm"
INCLUDE "home/fade.asm"


Serial:: ; 2125 (0:2125)
	push af
	push bc
	push de
	push hl
	ld a, [$ffaa]
	inc a
	jr z, .asm_2142
	ld a, [$ff01]
	ld [$ffad], a
	ld a, [$ffac]
	ld [$ff01], a
	ld a, [$ffaa]
	cp $2
	jr z, .asm_2162
	ld a, $80
	ld [$ff02], a
	jr .asm_2162
.asm_2142
	ld a, [$ff01]
	ld [$ffad], a
	ld [$ffaa], a
	cp $2
	jr z, .asm_215f
	xor a
	ld [$ff01], a
	ld a, $3
	ld [rDIV], a ; $ff04
.asm_2153
	ld a, [rDIV] ; $ff04
	bit 7, a
	jr nz, .asm_2153
	ld a, $80
	ld [$ff02], a
	jr .asm_2162
.asm_215f
	xor a
	ld [$ff01], a
.asm_2162
	ld a, $1
	ld [$ffa9], a
	ld a, $fe
	ld [$ffac], a
	pop hl
	pop de
	pop bc
	pop af
	reti

Func_216f:: ; 216f (0:216f)
	ld a, $1
	ld [$ffab], a
.asm_2173
	ld a, [hl]
	ld [$ffac], a
	call Func_219a
	push bc
	ld b, a
	inc hl
	ld a, $30
.asm_217e
	dec a
	jr nz, .asm_217e
	ld a, [$ffab]
	and a
	ld a, b
	pop bc
	jr z, .asm_2192
	dec hl
	cp $fd
	jr nz, .asm_2173
	xor a
	ld [$ffab], a
	jr .asm_2173
.asm_2192
	ld [de], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, .asm_2173
	ret

Func_219a:: ; 219a (0:219a)
	xor a
	ld [$ffa9], a
	ld a, [$ffaa]
	cp $2
	jr nz, .asm_21a7
	ld a, $81
	ld [$ff02], a
.asm_21a7
	ld a, [$ffa9]
	and a
	jr nz, .asm_21f1
	ld a, [$ffaa]
	cp $1
	jr nz, .asm_21cc
	call Func_2237
	jr z, .asm_21cc
	call Func_2231
	push hl
	ld hl, wcc48
	inc [hl]
	jr nz, .asm_21c3
	dec hl
	inc [hl]
.asm_21c3
	pop hl
	call Func_2237
	jr nz, .asm_21a7
	jp Func_223f
.asm_21cc
	ld a, [rIE] ; $ffff
	and $f
	cp $8
	jr nz, .asm_21a7
	ld a, [W_NUMHITS] ; wd074
	dec a
	ld [W_NUMHITS], a ; wd074
	jr nz, .asm_21a7
	ld a, [wd075]
	dec a
	ld [wd075], a
	jr nz, .asm_21a7
	ld a, [$ffaa]
	cp $1
	jr z, .asm_21f1
	ld a, $ff
.asm_21ee
	dec a
	jr nz, .asm_21ee
.asm_21f1
	xor a
	ld [$ffa9], a
	ld a, [rIE] ; $ffff
	and $f
	sub $8
	jr nz, .asm_2204
	ld [W_NUMHITS], a ; wd074
	ld a, $50
	ld [wd075], a
.asm_2204
	ld a, [$ffad]
	cp $fe
	ret nz
	call Func_2237
	jr z, .asm_221f
	push hl
	ld hl, wcc48
	ld a, [hl]
	dec a
	ld [hld], a
	inc a
	jr nz, .asm_2219
	dec [hl]
.asm_2219
	pop hl
	call Func_2237
	jr z, Func_223f
.asm_221f
	ld a, [rIE] ; $ffff
	and $f
	cp $8
	ld a, $fe
	ret z
	ld a, [hl]
	ld [$ffac], a
	call DelayFrame
	jp Func_219a

Func_2231:: ; 2231 (0:2231)
	ld a, $f
.asm_2233
	dec a
	jr nz, .asm_2233
	ret

Func_2237:: ; 2237 (0:2237)
	push hl
	ld hl, wcc47
	ld a, [hli]
	or [hl]
	pop hl
	ret

Func_223f:: ; 223f (0:223f)
	dec a
	ld [wcc47], a
	ld [wcc48], a
	ret

Func_2247:: ; 2247 (0:2247)
	ld hl, wcc42
	ld de, wcc3d
	ld c, $2
	ld a, $1
	ld [$ffab], a
.asm_2253
	call DelayFrame
	ld a, [hl]
	ld [$ffac], a
	call Func_219a
	ld b, a
	inc hl
	ld a, [$ffab]
	and a
	ld a, $0
	ld [$ffab], a
	jr nz, .asm_2253
	ld a, b
	ld [de], a
	inc de
	dec c
	jr nz, .asm_2253
	ret

Func_226e:: ; 226e (0:226e)
	call SaveScreenTilesToBuffer1
	callab PrintWaitingText
	call Func_227f
	jp LoadScreenTilesFromBuffer1

Func_227f:: ; 227f (0:227f)
	ld a, $ff
	ld [wcc3e], a
.asm_2284
	call Func_22c3
	call DelayFrame
	call Func_2237
	jr z, .asm_22a0
	push hl
	ld hl, wcc48
	dec [hl]
	jr nz, .asm_229f
	dec hl
	dec [hl]
	jr nz, .asm_229f
	pop hl
	xor a
	jp Func_223f
.asm_229f
	pop hl
.asm_22a0
	ld a, [wcc3e]
	inc a
	jr z, .asm_2284
	ld b, $a
.asm_22a8
	call DelayFrame
	call Func_22c3
	dec b
	jr nz, .asm_22a8
	ld b, $a
.asm_22b3
	call DelayFrame
	call Func_22ed
	dec b
	jr nz, .asm_22b3
	ld a, [wcc3e]
	ld [wcc3d], a
	ret

Func_22c3:: ; 22c3 (0:22c3)
	call asm_22d7
	ld a, [wcc42]
	add $60
	ld [$ffac], a
	ld a, [$ffaa]
	cp $2
	jr nz, asm_22d7
	ld a, $81
	ld [$ff02], a
asm_22d7:: ; 22d7 (0:22d7)
	ld a, [$ffad]
	ld [wcc3d], a
	and $f0
	cp $60
	ret nz
	xor a
	ld [$ffad], a
	ld a, [wcc3d]
	and $f
	ld [wcc3e], a
	ret

Func_22ed:: ; 22ed (0:22ed)
	xor a
	ld [$ffac], a
	ld a, [$ffaa]
	cp $2
	ret nz
	ld a, $81
	ld [$ff02], a
	ret

Func_22fa:: ; 22fa (0:22fa)
	ld a, $2
	ld [$ff01], a
	xor a
	ld [$ffad], a
	ld a, $80
	ld [$ff02], a
	ret


; timer interrupt is apparently not invoked anyway
Timer:: ; 2306 (0:2306)
	reti


INCLUDE "home/audio.asm"


UpdateSprites:: ; 2429 (0:2429)
	ld a, [wcfcb]
	dec a
	ret nz
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, Bank(_UpdateSprites)
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	call _UpdateSprites
	pop af
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ret

INCLUDE "data/mart_inventories.asm"

TextScriptEndingChar:: ; 24d6 (0:24d6)
	db "@"
TextScriptEnd:: ; 24d7 (0:24d7)
	ld hl,TextScriptEndingChar
	ret

ExclamationText:: ; 24db (0:24db)
	TX_FAR _ExclamationText
	db "@"

GroundRoseText:: ; 24e0 (0:24e0)
	TX_FAR _GroundRoseText
	db "@"

BoulderText:: ; 24e5 (0:24e5)
	TX_FAR _BoulderText
	db "@"

MartSignText:: ; 24ea (0:24ea)
	TX_FAR _MartSignText
	db "@"

PokeCenterSignText:: ; 24ef (0:24ef)
	TX_FAR _PokeCenterSignText
	db "@"

Predef5CText:: ; 24f4 (0:24f4)
; XXX better label (what does predef $5C do?)
	db $08 ; asm
	predef PickupItem
	jp TextScriptEnd


INCLUDE "home/pic.asm"


ResetPlayerSpriteData:: ; 28a6 (0:28a6)
	ld hl, wSpriteStateData1
	call ResetPlayerSpriteData_ClearSpriteData
	ld hl, wSpriteStateData2
	call ResetPlayerSpriteData_ClearSpriteData
	ld a, $1
	ld [wSpriteStateData1], a
	ld [wSpriteStateData2 + $0e], a
	ld hl, wSpriteStateData1 + 4
	ld [hl], $3c     ; set Y screen pos
	inc hl
	inc hl
	ld [hl], $40     ; set X screen pos
	ret

; overwrites sprite data with zeroes
ResetPlayerSpriteData_ClearSpriteData:: ; 28c4 (0:28c4)
	ld bc, $10
	xor a
	jp FillMemory

Func_28cb:: ; 28cb (0:28cb)
	ld a, [wMusicHeaderPointer]
	and a
	jr nz, .asm_28dc
	ld a, [wd72c]
	bit 1, a
	ret nz
	ld a, $77
	ld [$ff24], a
	ret
.asm_28dc
	ld a, [wcfc9]
	and a
	jr z, .asm_28e7
	dec a
	ld [wcfc9], a
	ret
.asm_28e7
	ld a, [wcfc8]
	ld [wcfc9], a
	ld a, [$ff24]
	and a
	jr z, .asm_2903
	ld b, a
	and $f
	dec a
	ld c, a
	ld a, b
	and $f0
	swap a
	dec a
	swap a
	or c
	ld [$ff24], a
	ret
.asm_2903
	ld a, [wMusicHeaderPointer]
	ld b, a
	xor a
	ld [wMusicHeaderPointer], a
	ld a, $ff
	ld [wc0ee], a
	call PlaySound
	ld a, [wc0f0]
	ld [wc0ef], a
	ld a, b
	ld [wc0ee], a
	jp PlaySound

; this function is used to display sign messages, sprite dialog, etc.
; INPUT: [$ff8c] = sprite ID or text ID
DisplayTextID:: ; 2920 (0:2920)
	ld a,[H_LOADEDROMBANK]
	push af
	callba DisplayTextIDInit ; initialization
	ld hl,wcf11
	bit 0,[hl]
	res 0,[hl]
	jr nz,.skipSwitchToMapBank
	ld a,[W_CURMAP]
	call SwitchToMapRomBank
.skipSwitchToMapBank
	ld a,30 ; half a second
	ld [H_FRAMECOUNTER],a ; used as joypad poll timer
	ld hl,W_MAPTEXTPTR
	ld a,[hli]
	ld h,[hl]
	ld l,a ; hl = map text pointer
	ld d,$00
	ld a,[$ff8c] ; text ID
	ld [wcf13],a
	and a
	jp z,DisplayStartMenu
	cp a,$d3 ; safari game over
	jp z,DisplaySafariGameOverText
	cp a,$d0 ; fainted
	jp z,DisplayPokemonFaintedText
	cp a,$d1 ; blacked out
	jp z,DisplayPlayerBlackedOutText
	cp a,$d2 ; repel wore off
	jp z,DisplayRepelWoreOffText
	ld a,[W_NUMSPRITES] ; number of sprites
	ld e,a
	ld a,[$ff8c] ; sprite ID
	cp e
	jr z,.spriteHandling
	jr nc,.skipSpriteHandling
.spriteHandling
; get the text ID of the sprite
	push hl
	push de
	push bc
	callba Func_13074 ; update the graphics of the sprite the player is talking to (to face the right direction)
	pop bc
	pop de
	ld hl,W_MAPSPRITEDATA ; NPC text entries
	ld a,[$ff8c]
	dec a
	add a
	add l
	ld l,a
	jr nc,.noCarry
	inc h
.noCarry
	inc hl
	ld a,[hl] ; a = text ID of the sprite
	pop hl
.skipSpriteHandling
; look up the address of the text in the map's text entries
	dec a
	ld e,a
	sla e
	add hl,de
	ld a,[hli]
	ld h,[hl]
	ld l,a ; hl = address of the text
	ld a,[hl] ; a = first byte of text
; check first byte of text for special cases
	cp a,$fe   ; Pokemart NPC
	jp z,DisplayPokemartDialogue
	cp a,$ff   ; Pokemon Center NPC
	jp z,DisplayPokemonCenterDialogue
	cp a,$fc   ; Item Storage PC
	jp z,FuncTX_ItemStoragePC
	cp a,$fd   ; Bill's PC
	jp z,FuncTX_BillsPC
	cp a,$f9   ; Pokemon Center PC
	jp z,FuncTX_PokemonCenterPC
	cp a,$f5   ; Vending Machine
	jr nz,.notVendingMachine
	callba VendingMachineMenu 	; jump banks to vending machine routine
	jr AfterDisplayingTextID
.notVendingMachine
	cp a,$f7   ; slot machine
	jp z,FuncTX_SlotMachine
	cp a,$f6   ; cable connection NPC in Pokemon Center
	jr nz,.notSpecialCase
	callab CableClubNPC
	jr AfterDisplayingTextID
.notSpecialCase
	call Func_3c59 ; display the text
	ld a,[wcc3c]
	and a
	jr nz,HoldTextDisplayOpen

AfterDisplayingTextID:: ; 29d6 (0:29d6)
	ld a,[wcc47]
	and a
	jr nz,HoldTextDisplayOpen
	call WaitForTextScrollButtonPress ; wait for a button press after displaying all the text

; loop to hold the dialogue box open as long as the player keeps holding down the A button
HoldTextDisplayOpen:: ; 29df (0:29df)
	call Joypad
	ld a,[hJoyHeld]
	bit 0,a ; is the A button being pressed?
	jr nz,HoldTextDisplayOpen

CloseTextDisplay:: ; 29e8 (0:29e8)
	ld a,[W_CURMAP]
	call SwitchToMapRomBank
	ld a,$90
	ld [$ffb0],a ; move the window off the screen
	call DelayFrame
	call LoadGBPal
	xor a
	ld [H_AUTOBGTRANSFERENABLED],a ; disable continuous WRAM to VRAM transfer each V-blank
; loop to make sprites face the directions they originally faced before the dialogue
	ld hl,wSpriteStateData2 + $19
	ld c,$0f
	ld de,$0010
.restoreSpriteFacingDirectionLoop
	ld a,[hl]
	dec h
	ld [hl],a
	inc h
	add hl,de
	dec c
	jr nz,.restoreSpriteFacingDirectionLoop
	ld a,BANK(InitMapSprites)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call InitMapSprites ; reload sprite tile pattern data (since it was partially overwritten by text tile patterns)
	ld hl,wcfc4
	res 0,[hl]
	ld a,[wd732]
	bit 3,a
	call z,LoadPlayerSpriteGraphics
	call LoadCurrentMapView
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	jp UpdateSprites ; move sprites

DisplayPokemartDialogue:: ; 2a2e (0:2a2e)
	push hl
	ld hl,PokemartGreetingText
	call PrintText
	pop hl
	inc hl
	call LoadItemList
	ld a,$02
	ld [wListMenuID],a ; selects between subtypes of menus
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,Bank(DisplayPokemartDialogue_)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call DisplayPokemartDialogue_
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	jp AfterDisplayingTextID

PokemartGreetingText:: ; 2a55 (0:2a55)
	TX_FAR _PokemartGreetingText
	db "@"

LoadItemList:: ; 2a5a (0:2a5a)
	ld a,$01
	ld [wcfcb],a
	ld a,h
	ld [wd128],a
	ld a,l
	ld [wd129],a
	ld de,wStringBuffer2 + 11
.loop
	ld a,[hli]
	ld [de],a
	inc de
	cp a,$ff
	jr nz,.loop
	ret

DisplayPokemonCenterDialogue:: ; 2a72 (0:2a72)
	xor a
	ld [$ff8b],a
	ld [$ff8c],a
	ld [$ff8d],a
	inc hl
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,Bank(DisplayPokemonCenterDialogue_)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call DisplayPokemonCenterDialogue_
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	jp AfterDisplayingTextID

DisplaySafariGameOverText:: ; 2a90 (0:2a90)
	callab PrintSafariGameOverText
	jp AfterDisplayingTextID

DisplayPokemonFaintedText:: ; 2a9b (0:2a9b)
	ld hl,PokemonFaintedText
	call PrintText
	jp AfterDisplayingTextID

PokemonFaintedText:: ; 2aa4 (0:2aa4)
	TX_FAR _PokemonFaintedText
	db "@"

DisplayPlayerBlackedOutText:: ; 2aa9 (0:2aa9)
	ld hl,PlayerBlackedOutText
	call PrintText
	ld a,[wd732]
	res 5,a
	ld [wd732],a
	jp HoldTextDisplayOpen

PlayerBlackedOutText:: ; 2aba (0:2aba)
	TX_FAR _PlayerBlackedOutText
	db "@"

DisplayRepelWoreOffText:: ; 2abf (0:2abf)
	ld hl,RepelWoreOffText
	call PrintText
	jp AfterDisplayingTextID

RepelWoreOffText:: ; 2ac8 (0:2ac8)
	TX_FAR _RepelWoreOffText
	db "@"

INCLUDE "engine/menu/start_menu.asm"

; function to count how many bits are set in a string of bytes
; INPUT:
; hl = address of string of bytes
; b = length of string of bytes
; OUTPUT:
; [wd11e] = number of set bits
CountSetBits:: ; 2b7f (0:2b7f)
	ld c,0
.loop
	ld a,[hli]
	ld e,a
	ld d,8
.innerLoop ; count how many bits are set in the current byte
	srl e
	ld a,0
	adc c
	ld c,a
	dec d
	jr nz,.innerLoop
	dec b
	jr nz,.loop
	ld a,c
	ld [wd11e],a ; store number of set bits
	ret

; subtracts the amount the player paid from their money
; sets carry flag if there is enough money and unsets carry flag if not
SubtractAmountPaidFromMoney:: ; 2b96 (0:2b96)
	ld b,BANK(SubtractAmountPaidFromMoney_)
	ld hl,SubtractAmountPaidFromMoney_
	jp Bankswitch

; adds the amount the player sold to their money
AddAmountSoldToMoney:: ; 2b9e (0:2b9e)
	ld de,wPlayerMoney + 2
	ld hl,$ffa1 ; total price of items
	ld c,3 ; length of money in bytes
	predef AddBCDPredef ; add total price to money
	ld a,$13
	ld [wd125],a
	call DisplayTextBoxID ; redraw money text box
	ld a, (SFX_02_5a - SFX_Headers_02) / 3
	call PlaySoundWaitForCurrent ; play sound
	jp WaitForSoundToFinish ; wait until sound is done playing

; function to remove an item (in varying quantities) from the player's bag or PC box
; INPUT:
; HL = address of inventory (either wNumBagItems or wNumBoxItems)
; [wWhichPokemon] = index (within the inventory) of the item to remove
; [wcf96] = quantity to remove
RemoveItemFromInventory:: ; 2bbb (0:2bbb)
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,BANK(RemoveItemFromInventory_)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call RemoveItemFromInventory_
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; function to add an item (in varying quantities) to the player's bag or PC box
; INPUT:
; HL = address of inventory (either wNumBagItems or wNumBoxItems)
; [wcf91] = item ID
; [wcf96] = item quantity
; sets carry flag if successful, unsets carry flag if unsuccessful
AddItemToInventory:: ; 2bcf (0:2bcf)
	push bc
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,BANK(AddItemToInventory_)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call AddItemToInventory_
	pop bc
	ld a,b
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	pop bc
	ret

; INPUT:
; [wListMenuID] = list menu ID
; [wcf8b] = address of the list (2 bytes)
DisplayListMenuID:: ; 2be6 (0:2be6)
	xor a
	ld [H_AUTOBGTRANSFERENABLED],a ; disable auto-transfer
	ld a,1
	ld [$ffb7],a ; joypad state update flag
	ld a,[W_BATTLETYPE]
	and a ; is it the Old Man battle?
	jr nz,.specialBattleType
	ld a,$01 ; hardcoded bank
	jr .bankswitch
.specialBattleType ; Old Man battle
	ld a, Bank(OldManItemList)
.bankswitch
	call BankswitchHome
	ld hl,wd730
	set 6,[hl] ; turn off letter printing delay
	xor a
	ld [wcc35],a ; 0 means no item is currently being swapped
	ld [wd12a],a
	ld a,[wcf8b]
	ld l,a
	ld a,[wcf8c]
	ld h,a ; hl = address of the list
	ld a,[hl]
	ld [wd12a],a ; [wd12a] = number of list entries
	ld a,$0d ; list menu text box ID
	ld [wd125],a
	call DisplayTextBoxID ; draw the menu text box
	call UpdateSprites ; move sprites
	FuncCoord 4,2 ; coordinates of upper left corner of menu text box
	ld hl,Coord
	ld de,$090e ; height and width of menu text box
	ld a,[wListMenuID]
	and a ; is it a PC pokemon list?
	jr nz,.skipMovingSprites
	call UpdateSprites ; move sprites
.skipMovingSprites
	ld a,1 ; max menu item ID is 1 if the list has less than 2 entries
	ld [wcc37],a
	ld a,[wd12a]
	cp a,2 ; does the list have less than 2 entries?
	jr c,.setMenuVariables
	ld a,2 ; max menu item ID is 2 if the list has at least 2 entries
.setMenuVariables
	ld [wMaxMenuItem],a
	ld a,4
	ld [wTopMenuItemY],a
	ld a,5
	ld [wTopMenuItemX],a
	ld a,%00000111 ; A button, B button, Select button
	ld [wMenuWatchedKeys],a
	ld c,10
	call DelayFrames

DisplayListMenuIDLoop:: ; 2c53 (0:2c53)
	xor a
	ld [H_AUTOBGTRANSFERENABLED],a ; disable transfer
	call PrintListMenuEntries
	ld a,1
	ld [H_AUTOBGTRANSFERENABLED],a ; enable transfer
	call Delay3
	ld a,[W_BATTLETYPE]
	and a ; is it the Old Man battle?
	jr z,.notOldManBattle
.oldManBattle
	ld a,"▶"
	FuncCoord 5,4
	ld [Coord],a ; place menu cursor in front of first menu entry
	ld c,80
	call DelayFrames
	xor a
	ld [wCurrentMenuItem],a
	ld hl,Coord
	ld a,l
	ld [wMenuCursorLocation],a
	ld a,h
	ld [wMenuCursorLocation + 1],a
	jr .buttonAPressed
.notOldManBattle
	call LoadGBPal
	call HandleMenuInput
	push af
	call PlaceMenuCursor
	pop af
	bit 0,a ; was the A button pressed?
	jp z,.checkOtherKeys
.buttonAPressed
	ld a,[wCurrentMenuItem]
	call PlaceUnfilledArrowMenuCursor
	ld a,$01
	ld [wd12e],a
	ld [wd12d],a
	xor a
	ld [wcc37],a
	ld a,[wCurrentMenuItem]
	ld c,a
	ld a,[wListScrollOffset]
	add c
	ld c,a
	ld a,[wd12a] ; number of list entries
	and a ; is the list empty?
	jp z,ExitListMenu ; if so, exit the menu
	dec a
	cp c ; did the player select Cancel?
	jp c,ExitListMenu ; if so, exit the menu
	ld a,c
	ld [wWhichPokemon],a
	ld a,[wListMenuID]
	cp a,ITEMLISTMENU
	jr nz,.skipMultiplying
; if it's an item menu
	sla c ; item entries are 2 bytes long, so multiply by 2
.skipMultiplying
	ld a,[wcf8b]
	ld l,a
	ld a,[wcf8c]
	ld h,a
	inc hl ; hl = beginning of list entries
	ld b,0
	add hl,bc
	ld a,[hl]
	ld [wcf91],a
	ld a,[wListMenuID]
	and a ; is it a PC pokemon list?
	jr z,.pokemonList
	push hl
	call GetItemPrice
	pop hl
	ld a,[wListMenuID]
	cp a,ITEMLISTMENU
	jr nz,.skipGettingQuantity
; if it's an item menu
	inc hl
	ld a,[hl] ; a = item quantity
	ld [wcf97],a
.skipGettingQuantity
	ld a,[wcf91]
	ld [wd0b5],a
	ld a,$01
	ld [wPredefBank],a
	call GetName
	jr .storeChosenEntry
.pokemonList
	ld hl,wPartyCount
	ld a,[wcf8b]
	cp l ; is it a list of party pokemon or box pokemon?
	ld hl,wPartyMonNicks
	jr z,.getPokemonName
	ld hl, wBoxMonNicks ; box pokemon names
.getPokemonName
	ld a,[wWhichPokemon]
	call GetPartyMonName
.storeChosenEntry ; store the menu entry that the player chose and return
	ld de,wcd6d
	call CopyStringToCF4B ; copy name to wcf4b
	ld a,$01
	ld [wd12e],a
	ld a,[wCurrentMenuItem]
	ld [wd12d],a
	xor a
	ld [$ffb7],a ; joypad state update flag
	ld hl,wd730
	res 6,[hl] ; turn on letter printing delay
	jp BankswitchBack
.checkOtherKeys ; check B, SELECT, Up, and Down keys
	bit 1,a ; was the B button pressed?
	jp nz,ExitListMenu ; if so, exit the menu
	bit 2,a ; was the select button pressed?
	jp nz,HandleItemListSwapping ; if so, allow the player to swap menu entries
	ld b,a
	bit 7,b ; was Down pressed?
	ld hl,wListScrollOffset
	jr z,.upPressed
.downPressed
	ld a,[hl]
	add a,3
	ld b,a
	ld a,[wd12a] ; number of list entries
	cp b ; will going down scroll past the Cancel button?
	jp c,DisplayListMenuIDLoop
	inc [hl] ; if not, go down
	jp DisplayListMenuIDLoop
.upPressed
	ld a,[hl]
	and a
	jp z,DisplayListMenuIDLoop
	dec [hl]
	jp DisplayListMenuIDLoop

DisplayChooseQuantityMenu:: ; 2d57 (0:2d57)
; text box dimensions/coordinates for just quantity
	FuncCoord 15,9
	ld hl,Coord
	ld b,1 ; height
	ld c,3 ; width
	ld a,[wListMenuID]
	cp a,PRICEDITEMLISTMENU
	jr nz,.drawTextBox
; text box dimensions/coordinates for quantity and price
	FuncCoord 7,9
	ld hl,Coord
	ld b,1  ; height
	ld c,11 ; width
.drawTextBox
	call TextBoxBorder
	FuncCoord 16,10
	ld hl,Coord
	ld a,[wListMenuID]
	cp a,PRICEDITEMLISTMENU
	jr nz,.printInitialQuantity
	FuncCoord 8,10
	ld hl,Coord
.printInitialQuantity
	ld de,InitialQuantityText
	call PlaceString
	xor a
	ld [wcf96],a ; initialize current quantity to 0
	jp .incrementQuantity
.waitForKeyPressLoop
	call JoypadLowSensitivity
	ld a,[hJoyPressed] ; newly pressed buttons
	bit 0,a ; was the A button pressed?
	jp nz,.buttonAPressed
	bit 1,a ; was the B button pressed?
	jp nz,.buttonBPressed
	bit 6,a ; was Up pressed?
	jr nz,.incrementQuantity
	bit 7,a ; was Down pressed?
	jr nz,.decrementQuantity
	jr .waitForKeyPressLoop
.incrementQuantity
	ld a,[wcf97] ; max quantity
	inc a
	ld b,a
	ld hl,wcf96 ; current quantity
	inc [hl]
	ld a,[hl]
	cp b
	jr nz,.handleNewQuantity
; wrap to 1 if the player goes above the max quantity
	ld a,1
	ld [hl],a
	jr .handleNewQuantity
.decrementQuantity
	ld hl,wcf96 ; current quantity
	dec [hl]
	jr nz,.handleNewQuantity
; wrap to the max quantity if the player goes below 1
	ld a,[wcf97] ; max quantity
	ld [hl],a
.handleNewQuantity
	FuncCoord 17,10
	ld hl,Coord
	ld a,[wListMenuID]
	cp a,PRICEDITEMLISTMENU
	jr nz,.printQuantity
.printPrice
	ld c,$03
	ld a,[wcf96]
	ld b,a
	ld hl,$ff9f ; total price
; initialize total price to 0
	xor a
	ld [hli],a
	ld [hli],a
	ld [hl],a
.addLoop ; loop to multiply the individual price by the quantity to get the total price
	ld de,$ffa1
	ld hl,$ff8d
	push bc
	predef AddBCDPredef ; add the individual price to the current sum
	pop bc
	dec b
	jr nz,.addLoop
	ld a,[$ff8e]
	and a ; should the price be halved (for selling items)?
	jr z,.skipHalvingPrice
	xor a
	ld [$ffa2],a
	ld [$ffa3],a
	ld a,$02
	ld [$ffa4],a
	predef DivideBCDPredef3 ; halves the price
; store the halved price
	ld a,[$ffa2]
	ld [$ff9f],a
	ld a,[$ffa3]
	ld [$ffa0],a
	ld a,[$ffa4]
	ld [$ffa1],a
.skipHalvingPrice
	FuncCoord 12,10
	ld hl,Coord
	ld de,SpacesBetweenQuantityAndPriceText
	call PlaceString
	ld de,$ff9f ; total price
	ld c,$a3
	call PrintBCDNumber
	FuncCoord 9,10
	ld hl,Coord
.printQuantity
	ld de,wcf96 ; current quantity
	ld bc,$8102 ; print leading zeroes, 1 byte, 2 digits
	call PrintNumber
	jp .waitForKeyPressLoop
.buttonAPressed ; the player chose to make the transaction
	xor a
	ld [wcc35],a ; 0 means no item is currently being swapped
	ret
.buttonBPressed ; the player chose to cancel the transaction
	xor a
	ld [wcc35],a ; 0 means no item is currently being swapped
	ld a,$ff
	ret

InitialQuantityText:: ; 2e30 (0:2e30)
	db "×01@"

SpacesBetweenQuantityAndPriceText:: ; 2e34 (0:2e34)
	db "      @"

ExitListMenu:: ; 2e3b (0:2e3b)
	ld a,[wCurrentMenuItem]
	ld [wd12d],a
	ld a,$02
	ld [wd12e],a
	ld [wcc37],a
	xor a
	ld [$ffb7],a
	ld hl,wd730
	res 6,[hl]
	call BankswitchBack
	xor a
	ld [wcc35],a ; 0 means no item is currently being swapped
	scf
	ret

PrintListMenuEntries:: ; 2e5a (0:2e5a)
	FuncCoord 5, 3
	ld hl,Coord
	ld b,$09
	ld c,$0e
	call ClearScreenArea
	ld a,[wcf8b]
	ld e,a
	ld a,[wcf8c]
	ld d,a
	inc de ; de = beginning of list entries
	ld a,[wListScrollOffset]
	ld c,a
	ld a,[wListMenuID]
	cp a,ITEMLISTMENU
	ld a,c
	jr nz,.skipMultiplying
; if it's an item menu
; item entries are 2 bytes long, so multiply by 2
	sla a
	sla c
.skipMultiplying
	add e
	ld e,a
	jr nc,.noCarry
	inc d
.noCarry
	FuncCoord 6,4 ; coordinates of first list entry name
	ld hl,Coord
	ld b,4 ; print 4 names
.loop
	ld a,b
	ld [wWhichPokemon],a
	ld a,[de]
	ld [wd11e],a
	cp a,$ff
	jp z,.printCancelMenuItem
	push bc
	push de
	push hl
	push hl
	push de
	ld a,[wListMenuID]
	and a
	jr z,.pokemonPCMenu
	cp a,$01
	jr z,.movesMenu
.itemMenu
	call GetItemName
	jr .placeNameString
.pokemonPCMenu
	push hl
	ld hl,wPartyCount
	ld a,[wcf8b]
	cp l ; is it a list of party pokemon or box pokemon?
	ld hl,wPartyMonNicks
	jr z,.getPokemonName
	ld hl, wBoxMonNicks ; box pokemon names
.getPokemonName
	ld a,[wWhichPokemon]
	ld b,a
	ld a,4
	sub b
	ld b,a
	ld a,[wListScrollOffset]
	add b
	call GetPartyMonName
	pop hl
	jr .placeNameString
.movesMenu
	call GetMoveName
.placeNameString
	call PlaceString
	pop de
	pop hl
	ld a,[wcf93]
	and a ; should prices be printed?
	jr z,.skipPrintingItemPrice
.printItemPrice
	push hl
	ld a,[de]
	ld de,ItemPrices
	ld [wcf91],a
	call GetItemPrice ; get price
	pop hl
	ld bc,20 + 5 ; 1 row down and 5 columns right
	add hl,bc
	ld c,$a3 ; no leading zeroes, right-aligned, print currency symbol, 3 bytes
	call PrintBCDNumber
.skipPrintingItemPrice
	ld a,[wListMenuID]
	and a
	jr nz,.skipPrintingPokemonLevel
.printPokemonLevel
	ld a,[wd11e]
	push af
	push hl
	ld hl,wPartyCount
	ld a,[wcf8b]
	cp l ; is it a list of party pokemon or box pokemon?
	ld a,$00
	jr z,.next
	ld a,$02
.next
	ld [wcc49],a
	ld hl,wWhichPokemon
	ld a,[hl]
	ld b,a
	ld a,$04
	sub b
	ld b,a
	ld a,[wListScrollOffset]
	add b
	ld [hl],a
	call LoadMonData ; load pokemon info
	ld a,[wcc49]
	and a ; is it a list of party pokemon or box pokemon?
	jr z,.skipCopyingLevel
.copyLevel
	ld a,[wcf9b]
	ld [wcfb9],a
.skipCopyingLevel
	pop hl
	ld bc,$001c
	add hl,bc
	call PrintLevel ; print level
	pop af
	ld [wd11e],a
.skipPrintingPokemonLevel
	pop hl
	pop de
	inc de
	ld a,[wListMenuID]
	cp a,ITEMLISTMENU
	jr nz,.nextListEntry
.printItemQuantity
	ld a,[wd11e]
	ld [wcf91],a
	call IsKeyItem ; check if item is unsellable
	ld a,[wd124]
	and a ; is the item unsellable?
	jr nz,.skipPrintingItemQuantity ; if so, don't print the quantity
	push hl
	ld bc,20 + 8 ; 1 row down and 8 columns right
	add hl,bc
	ld a,"×"
	ldi [hl],a
	ld a,[wd11e]
	push af
	ld a,[de]
	ld [wcf97],a
	push de
	ld de,wd11e
	ld [de],a
	ld bc,$0102
	call PrintNumber
	pop de
	pop af
	ld [wd11e],a
	pop hl
.skipPrintingItemQuantity
	inc de
	pop bc
	inc c
	push bc
	inc c
	ld a,[wcc35] ; ID of item chosen for swapping (counts from 1)
	and a ; is an item being swapped?
	jr z,.nextListEntry
	sla a
	cp c ; is it this item?
	jr nz,.nextListEntry
	dec hl
	ld a,$ec ; unfilled right arrow menu cursor to indicate an item being swapped
	ld [hli],a
.nextListEntry
	ld bc,2 * 20 ; 2 rows
	add hl,bc
	pop bc
	inc c
	dec b
	jp nz,.loop
	ld bc,-8
	add hl,bc
	ld a,$ee ; down arrow
	ld [hl],a
	ret
.printCancelMenuItem
	ld de,ListMenuCancelText
	jp PlaceString

ListMenuCancelText:: ; 2f97 (0:2f97)
	db "CANCEL@"

GetMonName:: ; 2f9e (0:2f9e)
	push hl
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,BANK(MonsterNames) ; 07
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ld a,[wd11e]
	dec a
	ld hl,MonsterNames ; 421E
	ld c,10
	ld b,0
	call AddNTimes
	ld de,wcd6d
	push de
	ld bc,10
	call CopyData
	ld hl,wcd77
	ld [hl], "@"
	pop de
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	pop hl
	ret

GetItemName:: ; 2fcf (0:2fcf)
; given an item ID at [wd11e], store the name of the item into a string
;     starting at wcd6d
	push hl
	push bc
	ld a,[wd11e]
	cp HM_01 ; is this a TM/HM?
	jr nc,.Machine

	ld [wd0b5],a
	ld a,ITEM_NAME
	ld [W_LISTTYPE],a
	ld a,BANK(ItemNames)
	ld [wPredefBank],a
	call GetName
	jr .Finish

.Machine
	call GetMachineName
.Finish
	ld de,wcd6d ; pointer to where item name is stored in RAM
	pop bc
	pop hl
	ret

GetMachineName:: ; 2ff3 (0:2ff3)
; copies the name of the TM/HM in [wd11e] to wcd6d
	push hl
	push de
	push bc
	ld a,[wd11e]
	push af
	cp TM_01 ; is this a TM? [not HM]
	jr nc,.WriteTM
; if HM, then write "HM" and add 5 to the item ID, so we can reuse the
; TM printing code
	add 5
	ld [wd11e],a
	ld hl,HiddenPrefix ; points to "HM"
	ld bc,2
	jr .WriteMachinePrefix
.WriteTM
	ld hl,TechnicalPrefix ; points to "TM"
	ld bc,2
.WriteMachinePrefix
	ld de,wcd6d
	call CopyData

; now get the machine number and convert it to text
	ld a,[wd11e]
	sub TM_01 - 1
	ld b,$F6 ; "0"
.FirstDigit
	sub 10
	jr c,.SecondDigit
	inc b
	jr .FirstDigit
.SecondDigit
	add 10
	push af
	ld a,b
	ld [de],a
	inc de
	pop af
	ld b,$F6 ; "0"
	add b
	ld [de],a
	inc de
	ld a,"@"
	ld [de],a

	pop af
	ld [wd11e],a
	pop bc
	pop de
	pop hl
	ret

TechnicalPrefix:: ; 303c (0:303c)
	db "TM"
HiddenPrefix:: ; 303e (0:303e)
	db "HM"

; sets carry if item is HM, clears carry if item is not HM
; Input: a = item ID
IsItemHM:: ; 3040 (0:3040)
	cp a,HM_01
	jr c,.notHM
	cp a,TM_01
	ret
.notHM
	and a
	ret

; sets carry if move is an HM, clears carry if move is not an HM
; Input: a = move ID
IsMoveHM:: ; 3049 (0:3049)
	ld hl,HMMoves
	ld de,1
	jp IsInArray

HMMoves:: ; 3052 (0:3052)
	db CUT,FLY,SURF,STRENGTH,FLASH
	db $ff ; terminator

GetMoveName:: ; 3058 (0:3058)
	push hl
	ld a,MOVE_NAME
	ld [W_LISTTYPE],a
	ld a,[wd11e]
	ld [wd0b5],a
	ld a,BANK(MoveNames)
	ld [wPredefBank],a
	call GetName
	ld de,wcd6d ; pointer to where move name is stored in RAM
	pop hl
	ret

; reloads text box tile patterns, current map view, and tileset tile patterns
ReloadMapData:: ; 3071 (0:3071)
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,[W_CURMAP]
	call SwitchToMapRomBank
	call DisableLCD
	call LoadTextBoxTilePatterns
	call LoadCurrentMapView
	call LoadTilesetTilePatternData
	call EnableLCD
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; reloads tileset tile patterns
ReloadTilesetTilePatterns:: ; 3090 (0:3090)
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,[W_CURMAP]
	call SwitchToMapRomBank
	call DisableLCD
	call LoadTilesetTilePatternData
	call EnableLCD
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; shows the town map and lets the player choose a destination to fly to
ChooseFlyDestination:: ; 30a9 (0:30a9)
	ld hl,wd72e
	res 4,[hl]
	ld b, BANK(LoadTownMap_Fly)
	ld hl, LoadTownMap_Fly
	jp Bankswitch

; causes the text box to close waithout waiting for a button press after displaying text
DisableWaitingAfterTextDisplay:: ; 30b6 (0:30b6)
	ld a,$01
	ld [wcc3c],a
	ret

; uses an item
; UseItem is used with dummy items to perform certain other functions as well
; INPUT:
; [wcf91] = item ID
; OUTPUT:
; [wcd6a] = success
; 00: unsucessful
; 01: successful
; 02: not able to be used right now, no extra menu displayed (only certain items use this)
UseItem:: ; 30bc (0:30bc)
	ld b,BANK(UseItem_)
	ld hl,UseItem_
	jp Bankswitch

; confirms the item toss and then tosses the item
; INPUT:
; hl = address of inventory (either wNumBagItems or wNumBoxItems)
; [wcf91] = item ID
; [wWhichPokemon] = index of item within inventory
; [wcf96] = quantity to toss
; OUTPUT:
; clears carry flag if the item is tossed, sets carry flag if not
TossItem:: ; 30c4 (0:30c4)
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,BANK(TossItem_)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call TossItem_
	pop de
	ld a,d
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; checks if an item is a key item
; INPUT:
; [wcf91] = item ID
; OUTPUT:
; [wd124] = result
; 00: item is not key item
; 01: item is key item
IsKeyItem:: ; 30d9 (0:30d9)
	push hl
	push de
	push bc
	callba IsKeyItem_
	pop bc
	pop de
	pop hl
	ret

; function to draw various text boxes
; INPUT:
; [wd125] = text box ID
DisplayTextBoxID:: ; 30e8 (0:30e8)
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,BANK(DisplayTextBoxID_)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call DisplayTextBoxID_
	pop bc
	ld a,b
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

Func_30fd:: ; 30fd (0:30fd)
	ld a, [wcc57]
	and a
	ret nz
	ld a, [wd736]
	bit 1, a
	ret nz
	ld a, [wd730]
	and $80
	ret

Func_310e:: ; 310e (0:310e)
	ld hl, wd736
	bit 0, [hl]
	res 0, [hl]
	jr nz, .asm_3146
	ld a, [wcc57]
	and a
	ret z
	dec a
	add a
	ld d, $0
	ld e, a
	ld hl, .pointerTable_3140
	add hl, de
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, [wcc58]
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ld a, [wcf10]
	call CallFunctionInTable
	pop af
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ret
.pointerTable_3140
	dw PointerTable_1a442
	dw PointerTable_1a510
	dw PointerTable_1a57d
.asm_3146
	ld b, BANK(Func_1a3e0)
	ld hl, Func_1a3e0
	jp Bankswitch

Func_314e:: ; 314e (0:314e)
	ld b, BANK(Func_1a41d)
	ld hl, Func_1a41d
	jp Bankswitch

Func_3156:: ; 3156 (0:3156)
	ret

; stores hl in [W_TRAINERHEADERPTR]
StoreTrainerHeaderPointer:: ; 3157 (0:3157)
	ld a, h
	ld [W_TRAINERHEADERPTR], a
	ld a, l
	ld [W_TRAINERHEADERPTR+1], a
	ret

; executes the current map script from the function pointer array provided in hl.
; a: map script index to execute (unless overridden by [wd733] bit 4)
ExecuteCurMapScriptInTable:: ; 3160 (0:3160)
	push af
	push de
	call StoreTrainerHeaderPointer
	pop hl
	pop af
	push hl
	ld hl, W_FLAGS_D733
	bit 4, [hl]
	res 4, [hl]
	jr z, .useProvidedIndex   ; test if map script index was overridden manually
	ld a, [W_CURMAPSCRIPT]
.useProvidedIndex
	pop hl
	ld [W_CURMAPSCRIPT], a
	call CallFunctionInTable
	ld a, [W_CURMAPSCRIPT]
	ret

LoadGymLeaderAndCityName:: ; 317f (0:317f)
	push de
	ld de, wGymCityName
	ld bc, $11
	call CopyData   ; load city name
	pop hl
	ld de, wGymLeaderName
	ld bc, $b
	jp CopyData     ; load gym leader name

; reads specific information from trainer header (pointed to at W_TRAINERHEADERPTR)
; a: offset in header data
;    0 -> flag's bit (into wTrainerHeaderFlagBit)
;    2 -> flag's byte ptr (into hl)
;    4 -> before battle text (into hl)
;    6 -> after battle text (into hl)
;    8 -> end battle text (into hl)
ReadTrainerHeaderInfo:: ; 3193 (0:3193)
	push de
	push af
	ld d, $0
	ld e, a
	ld hl, W_TRAINERHEADERPTR
	ld a, [hli]
	ld l, [hl]
	ld h, a
	add hl, de
	pop af
	and a
	jr nz, .nonZeroOffset
	ld a, [hl]
	ld [wTrainerHeaderFlagBit], a  ; store flag's bit
	jr .done
.nonZeroOffset
	cp $2
	jr z, .readPointer ; read flag's byte ptr
	cp $4
	jr z, .readPointer ; read before battle text
	cp $6
	jr z, .readPointer ; read after battle text
	cp $8
	jr z, .readPointer ; read end battle text
	cp $a
	jr nz, .done
	ld a, [hli]        ; read end battle text (2) but override the result afterwards (XXX why, bug?)
	ld d, [hl]
	ld e, a
	jr .done
.readPointer
	ld a, [hli]
	ld h, [hl]
	ld l, a
.done
	pop de
	ret

TrainerFlagAction::
	predef_jump FlagActionPredef

; direct talking to a trainer (rather than getting seen by one)
TalkToTrainer:: ; 31cc (0:31cc)
	call StoreTrainerHeaderPointer
	xor a
	call ReadTrainerHeaderInfo     ; read flag's bit
	ld a, $2
	call ReadTrainerHeaderInfo     ; read flag's byte ptr
	ld a, [wTrainerHeaderFlagBit]
	ld c, a
	ld b, $2
	call TrainerFlagAction      ; read trainer's flag
	ld a, c
	and a
	jr z, .trainerNotYetFought     ; test trainer's flag
	ld a, $6
	call ReadTrainerHeaderInfo     ; print after battle text
	jp PrintText
.trainerNotYetFought ; 0x31ed
	ld a, $4
	call ReadTrainerHeaderInfo     ; print before battle text
	call PrintText
	ld a, $a
	call ReadTrainerHeaderInfo     ; (?) does nothing apparently (maybe bug in ReadTrainerHeaderInfo)
	push de
	ld a, $8
	call ReadTrainerHeaderInfo     ; read end battle text
	pop de
	call PreBattleSaveRegisters
	ld hl, W_FLAGS_D733
	set 4, [hl]                    ; activate map script index override (index is set below)
	ld hl, wFlags_0xcd60
	bit 0, [hl]                    ; test if player is already being engaged by another trainer
	ret nz
	call EngageMapTrainer
	ld hl, W_CURMAPSCRIPT
	inc [hl]      ; progress map script index (assuming it was 0 before) to start pre-battle routines
	jp Func_325d

; checks if any trainers are seeing the player and wanting to fight
CheckFightingMapTrainers:: ; 3219 (0:3219)
	call CheckForEngagingTrainers
	ld a, [wcf13]
	cp $ff
	jr nz, .trainerEngaging
	xor a
	ld [wcf13], a
	ld [wTrainerHeaderFlagBit], a
	ret
.trainerEngaging
	ld hl, W_FLAGS_D733
	set 3, [hl]
	ld [wcd4f], a
	xor a
	ld [wcd50], a
	predef EmotionBubble
	ld a, D_RIGHT | D_LEFT | D_UP | D_DOWN
	ld [wJoyIgnore], a
	xor a
	ldh [$b4], a
	call TrainerWalkUpToPlayer_Bank0
	ld hl, W_CURMAPSCRIPT
	inc [hl]      ; progress to battle phase 1 (engaging)
	ret

Func_324c:: ; 324c (0:324c)
	ld a, [wd730]
	and $1
	ret nz
	ld [wJoyIgnore], a
	ld a, [wcf13]
	ld [H_DOWNARROWBLINKCNT2], a ; $ff8c
	call DisplayTextID

Func_325d:: ; 325d (0:325d)
	xor a
	ld [wJoyIgnore], a
	call InitBattleEnemyParameters
	ld hl, wd72d
	set 6, [hl]
	set 7, [hl]
	ld hl, wd72e
	set 1, [hl]
	ld hl, W_CURMAPSCRIPT
	inc [hl]        ; progress to battle phase 2 (battling)
	ret

EndTrainerBattle:: ; 3275 (0:3275)
	ld hl, wd126
	set 5, [hl]
	set 6, [hl]
	ld hl, wd72d
	res 7, [hl]
	ld hl, wFlags_0xcd60
	res 0, [hl]                  ; player is no longer engaged by any trainer
	ld a, [W_ISINBATTLE] ; W_ISINBATTLE
	cp $ff
	jp z, ResetButtonPressedAndMapScript
	ld a, $2
	call ReadTrainerHeaderInfo
	ld a, [wTrainerHeaderFlagBit]
	ld c, a
	ld b, $1
	call TrainerFlagAction   ; flag trainer as fought
	ld a, [W_ENEMYMONORTRAINERCLASS]
	cp $c8
	jr nc, .skipRemoveSprite    ; test if trainer was fought (in that case skip removing the corresponding sprite)
	ld hl, W_MISSABLEOBJECTLIST
	ld de, $2
	ld a, [wcf13]
	call IsInArray              ; search for sprite ID
	inc hl
	ld a, [hl]
	ld [wcc4d], a               ; load corresponding missable object index and remove it
	predef HideObject
.skipRemoveSprite
	ld hl, wd730
	bit 4, [hl]
	res 4, [hl]
	ret nz

ResetButtonPressedAndMapScript:: ; 32c1 (0:32c1)
	xor a
	ld [wJoyIgnore], a
	ld [hJoyHeld], a
	ld [hJoyPressed], a
	ld [hJoyReleased], a
	ld [W_CURMAPSCRIPT], a               ; reset battle status
	ret

; calls TrainerWalkUpToPlayer
TrainerWalkUpToPlayer_Bank0:: ; 32cf (0:32cf)
	ld b, BANK(TrainerWalkUpToPlayer)
	ld hl, TrainerWalkUpToPlayer
	jp Bankswitch

; sets opponent type and mon set/lvl based on the engaging trainer data
InitBattleEnemyParameters:: ; 32d7 (0:32d7)
	ld a, [wEngagedTrainerClass]
	ld [W_CUROPPONENT], a ; wd059
	ld [W_ENEMYMONORTRAINERCLASS], a
	cp $c8
	ld a, [wEngagedTrainerSet] ; wcd2e
	jr c, .noTrainer
	ld [W_TRAINERNO], a ; wd05d
	ret
.noTrainer
	ld [W_CURENEMYLVL], a ; W_CURENEMYLVL
	ret

Func_32ef:: ; 32ef (0:32ef)
	ld hl, Func_567f9
	jr asm_3301

Func_32f4:: ; 32f4 (0:32f4)
	ld hl, Func_56819
	jr asm_3301 ; 0x32f7 $8

Func_32f9:: ; 32f9 (0:32f9)
	ld hl, Func_5683d
	jr asm_3301

Func_32fe:: ; 32fe (0:32fe)
	ld hl, Func_5685d
asm_3301:: ; 3301 (0:3301)
	ld b, BANK(Func_567f9) ; BANK(Func_56819), BANK(Func_5683d), BANK(Func_5685d)
	jp Bankswitch ; indirect jump to one of the four functions

CheckForEngagingTrainers:: ; 3306 (0:3306)
	xor a
	call ReadTrainerHeaderInfo       ; read trainer flag's bit (unused)
	ld d, h                          ; store trainer header address in de
	ld e, l
.trainerLoop
	call StoreTrainerHeaderPointer   ; set trainer header pointer to current trainer
	ld a, [de]
	ld [wcf13], a                     ; store trainer flag's bit
	ld [wTrainerHeaderFlagBit], a
	cp $ff
	ret z
	ld a, $2
	call ReadTrainerHeaderInfo       ; read trainer flag's byte ptr
	ld b, $2
	ld a, [wTrainerHeaderFlagBit]
	ld c, a
	call TrainerFlagAction        ; read trainer flag
	ld a, c
	and a
	jr nz, .trainerAlreadyFought
	push hl
	push de
	push hl
	xor a
	call ReadTrainerHeaderInfo       ; get trainer header pointer
	inc hl
	ld a, [hl]                       ; read trainer engage distance
	pop hl
	ld [wTrainerEngageDistance], a
	ld a, [wcf13]
	swap a
	ld [wTrainerSpriteOffset], a ; wWhichTrade
	predef TrainerEngage
	pop de
	pop hl
	ld a, [wTrainerSpriteOffset] ; wWhichTrade
	and a
	ret nz        ; break if the trainer is engaging
.trainerAlreadyFought
	ld hl, $c
	add hl, de
	ld d, h
	ld e, l
	jr .trainerLoop

; saves loaded rom bank and hl as well as de registers
PreBattleSaveRegisters:: ; 3354 (0:3354)
	ld a, [H_LOADEDROMBANK]
	ld [W_PBSTOREDROMBANK], a
	ld a, h
	ld [W_PBSTOREDREGISTERH], a
	ld a, l
	ld [W_PBSTOREDREGISTERL], a
	ld a, d
	ld [W_PBSTOREDREGISTERD], a
	ld a, e
	ld [W_PBSTOREDREGISTERE], a
	ret

; loads data of some trainer on the current map and plays pre-battle music
; [wcf13]: sprite ID of trainer who is engaged
EngageMapTrainer:: ; 336a (0:336a)
	ld hl, W_MAPSPRITEEXTRADATA
	ld d, $0
	ld a, [wcf13]
	dec a
	add a
	ld e, a
	add hl, de     ; seek to engaged trainer data
	ld a, [hli]    ; load trainer class
	ld [wEngagedTrainerClass], a
	ld a, [hl]     ; load trainer mon set
	ld [wEnemyMonAttackMod], a ; wcd2e
	jp PlayTrainerMusic

Func_3381:: ; 3381 (0:3381)
	push hl
	ld hl, wd72d
	bit 7, [hl]
	res 7, [hl]
	pop hl
	ret z
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, [W_PBSTOREDROMBANK]
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	push hl
	callba SaveTrainerName
	ld hl, TrainerNameText
	call PrintText
	pop hl
	pop af
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	callba Func_1a5e7
	jp WaitForSoundToFinish

Func_33b7:: ; 33b7 (0:33b7)
	ld a, [wcf0b]
	and a
	jr nz, .asm_33c6
	ld a, [W_PBSTOREDREGISTERH]
	ld h, a
	ld a, [W_PBSTOREDREGISTERL]
	ld l, a
	ret
.asm_33c6
	ld a, [W_PBSTOREDREGISTERD]
	ld h, a
	ld a, [W_PBSTOREDREGISTERE]
	ld l, a
	ret

TrainerNameText:: ; 33cf (0:33cf)
	TX_FAR _TrainerNameText
	db $08

Func_33d4:: ; 33d4 (0:33d4)
	call Func_33b7
	call TextCommandProcessor
	jp TextScriptEnd

Func_33dd:: ; 33dd (0:33dd)
	ld a, [wFlags_0xcd60]
	bit 0, a
	ret nz
	call EngageMapTrainer
	xor a
	ret

PlayTrainerMusic:: ; 33e8 (0:33e8)
	ld a, [wEngagedTrainerClass]
	cp $c8 + SONY1
	ret z
	cp $c8 + SONY2
	ret z
	cp $c8 + SONY3
	ret z
	ld a, [W_GYMLEADERNO] ; W_GYMLEADERNO
	and a
	ret nz
	xor a
	ld [wMusicHeaderPointer], a
	ld a, $ff
	call PlaySound      ; stop music
	ld a, BANK(Music_MeetEvilTrainer)
	ld [wc0ef], a
	ld [wc0f0], a
	ld a, [wEngagedTrainerClass]
	ld b, a
	ld hl, EvilTrainerList
.evilTrainerListLoop
	ld a, [hli]
	cp $ff
	jr z, .noEvilTrainer
	cp b
	jr nz, .evilTrainerListLoop
	ld a, MUSIC_MEET_EVIL_TRAINER
	jr .PlaySound
.noEvilTrainer
	ld hl, FemaleTrainerList
.femaleTrainerListLoop
	ld a, [hli]
	cp $ff
	jr z, .maleTrainer
	cp b
	jr nz, .femaleTrainerListLoop
	ld a, MUSIC_MEET_FEMALE_TRAINER
	jr .PlaySound
.maleTrainer
	ld a, MUSIC_MEET_MALE_TRAINER
.PlaySound
	ld [wc0ee], a
	jp PlaySound

INCLUDE "data/trainer_types.asm"

Func_3442:: ; 3442 (0:3442)
	ld a, [hli]
	cp $ff
	ret z
	cp b
	jr nz, .asm_345b
	ld a, [hli]
	cp c
	jr nz, .asm_345c
	ld a, [hli]
	ld d, [hl]
	ld e, a
	ld hl, wccd3
	call DecodeRLEList
	dec a
	ld [wcd38], a
	ret
.asm_345b
	inc hl
.asm_345c
	inc hl
	inc hl
	jr Func_3442

FuncTX_ItemStoragePC:: ; 3460 (0:3460)
	call SaveScreenTilesToBuffer2
	ld b, BANK(PlayerPC)
	ld hl, PlayerPC
	jr bankswitchAndContinue

FuncTX_BillsPC:: ; 346a (0:346a)
	call SaveScreenTilesToBuffer2
	ld b, BANK(Func_214c2)
	ld hl, Func_214c2
	jr bankswitchAndContinue

FuncTX_SlotMachine:: ; 3474 (0:3474)
; XXX find a better name for this function
; special_F7
	ld b,BANK(CeladonPrizeMenu)
	ld hl,CeladonPrizeMenu
bankswitchAndContinue:: ; 3479 (0:3479)
	call Bankswitch
	jp HoldTextDisplayOpen        ; continue to main text-engine function

FuncTX_PokemonCenterPC:: ; 347f (0:347f)
	ld b, BANK(ActivatePC)
	ld hl, ActivatePC
	jr bankswitchAndContinue

Func_3486:: ; 3486 (0:3486)
	xor a
	ld [wcd3b], a
	ld [wSpriteStateData2 + $06], a
	ld hl, wd730
	set 7, [hl]
	ret

IsItemInBag:: ; 3493 (0:3493)
; given an item_id in b
; set zero flag if item isn't in player's bag
; else reset zero flag
; related to Pokémon Tower and ghosts
	predef IsItemInBag_ 
	ld a,b
	and a
	ret

DisplayPokedex:: ; 349b (0:349b)
	ld [wd11e], a
	ld b, BANK(Func_7c18)
	ld hl, Func_7c18
	jp Bankswitch

Func_34a6:: ; 34a6 (0:34a6)
	call Func_34ae
	ld c, $6
	jp DelayFrames

Func_34ae:: ; 34ae (0:34ae)
	ld a, $9
	ld [H_DOWNARROWBLINKCNT1], a ; $ff8b
	call Func_34fc
	ld a, [$ff8d]
	ld [hl], a
	ret

Func_34b9:: ; 34b9 (0:34b9)
	ld de, $fff9
	add hl, de
	ld [hl], a
	ret

; tests if the player's coordinates are in a specified array
; INPUT:
; hl = address of array
; OUTPUT:
; [wWhichTrade] = if there is match, the matching array index
; sets carry if the coordinates are in the array, clears carry if not
ArePlayerCoordsInArray:: ; 34bf (0:34bf)
	ld a,[W_YCOORD]
	ld b,a
	ld a,[W_XCOORD]
	ld c,a
	; fallthrough

CheckCoords:: ; 34c7 (0:34c7)
	xor a
	ld [wWhichTrade],a
.loop
	ld a,[hli]
	cp a,$ff ; reached terminator?
	jr z,.notInArray
	push hl
	ld hl,wWhichTrade
	inc [hl]
	pop hl
.compareYCoord
	cp b
	jr z,.compareXCoord
	inc hl
	jr .loop
.compareXCoord
	ld a,[hli]
	cp c
	jr nz,.loop
.inArray
	scf
	ret
.notInArray
	and a
	ret

; tests if a boulder's coordinates are in a specified array
; INPUT:
; hl = address of array
; ff8c = which boulder to check? XXX
; OUTPUT:
; [wWhichTrade] = if there is match, the matching array index
; sets carry if the coordinates are in the array, clears carry if not
CheckBoulderCoords:: ; 34e4 (0:34e4)
	push hl
	ld hl, wSpriteStateData2 + $04
	ld a, [$ff8c]
	swap a
	ld d, $0
	ld e, a
	add hl, de
	ld a, [hli]
	sub $4 ; because sprite coordinates are offset by 4
	ld b, a
	ld a, [hl]
	sub $4 ; because sprite coordinates are offset by 4
	ld c, a
	pop hl
	jp CheckCoords

Func_34fc:: ; 34fc (0:34fc)
	ld h, $c1
	jr asm_3502

Func_3500:: ; 3500 (0:3500)
	ld h, $c2
asm_3502:: ; 3502 (0:3502)
	ld a, [H_DOWNARROWBLINKCNT1] ; $ff8b
	ld b, a
	ld a, [H_DOWNARROWBLINKCNT2] ; $ff8c
	swap a
	add b
	ld l, a
	ret

; decodes a $ff-terminated RLEncoded list
; each entry is a pair of bytes <byte value> <repetitions>
; the final $ff will be replicated in the output list and a contains the number of bytes written
; de: input list
; hl: output list
DecodeRLEList:: ; 350c (0:350c)
	xor a
	ld [wRLEByteCount], a     ; count written bytes here
.listLoop
	ld a, [de]
	cp $ff
	jr z, .endOfList
	ld [H_DOWNARROWBLINKCNT1], a ; store byte value to be written
	inc de
	ld a, [de]
	ld b, $0
	ld c, a                      ; number of bytes to be written
	ld a, [wRLEByteCount]
	add c
	ld [wRLEByteCount], a     ; update total number of written bytes
	ld a, [H_DOWNARROWBLINKCNT1] ; $ff8b
	call FillMemory              ; write a c-times to output
	inc de
	jr .listLoop
.endOfList
	ld a, $ff
	ld [hl], a                   ; write final $ff
	ld a, [wRLEByteCount]
	inc a                        ; include sentinel in counting
	ret

; sets movement byte 1 for sprite [$FF8C] to $FE and byte 2 to [$FF8D]
SetSpriteMovementBytesToFE:: ; 3533 (0:3533)
	push hl
	call GetSpriteMovementByte1Pointer
	ld [hl], $fe
	call GetSpriteMovementByte2Pointer
	ld a, [$ff8d]
	ld [hl], a
	pop hl
	ret

; sets both movement bytes for sprite [$FF8C] to $FF
SetSpriteMovementBytesToFF:: ; 3541 (0:3541)
	push hl
	call GetSpriteMovementByte1Pointer
	ld [hl],$FF
	call GetSpriteMovementByte2Pointer
	ld [hl],$FF ; prevent person from walking?
	pop hl
	ret

; returns the sprite movement byte 1 pointer for sprite [$FF8C] in hl
GetSpriteMovementByte1Pointer:: ; 354e (0:354e)
	ld h,$C2
	ld a,[$FF8C] ; the sprite to move
	swap a
	add a,6
	ld l,a
	ret

; returns the sprite movement byte 2 pointer for sprite [$FF8C] in hl
GetSpriteMovementByte2Pointer:: ; 3558 (0:3558)
	push de
	ld hl,W_MAPSPRITEDATA
	ld a,[$FF8C] ; the sprite to move
	dec a
	add a
	ld d,0
	ld e,a
	add hl,de
	pop de
	ret

GetTrainerInformation:: ; 3566 (0:3566)
	call GetTrainerName
	ld a, [W_ISLINKBATTLE] ; W_ISLINKBATTLE
	and a
	jr nz, .linkBattle
	ld a, Bank(TrainerPicAndMoneyPointers)
	call BankswitchHome
	ld a, [W_TRAINERCLASS] ; wd031
	dec a
	ld hl, TrainerPicAndMoneyPointers
	ld bc, $5
	call AddNTimes
	ld de, wd033
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hli]
	ld [de], a
	ld de, wd046
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hli]
	ld [de], a
	jp BankswitchBack
.linkBattle
	ld hl, wd033
	ld de, RedPicFront
	ld [hl], e
	inc hl
	ld [hl], d
	ret

GetTrainerName:: ; 359e (0:359e)
	ld b, BANK(GetTrainerName_)
	ld hl, GetTrainerName_
	jp Bankswitch


HasEnoughMoney::
; Check if the player has at least as much
; money as the 3-byte BCD value at $ff9f.
	ld de, wPlayerMoney
	ld hl, $ff9f
	ld c, 3
	jp StringCmp

HasEnoughCoins::
; Check if the player has at least as many
; coins as the 2-byte BCD value at $ffa0.
	ld de, wPlayerCoins
	ld hl, $ffa0
	ld c, 2
	jp StringCmp


BankswitchHome:: ; 35bc (0:35bc)
; switches to bank # in a
; Only use this when in the home bank!
	ld [wcf09],a
	ld a,[H_LOADEDROMBANK]
	ld [wcf08],a
	ld a,[wcf09]
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

BankswitchBack:: ; 35cd (0:35cd)
; returns from BankswitchHome
	ld a,[wcf08]
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

Bankswitch:: ; 35d6 (0:35d6)
; self-contained bankswitch, use this when not in the home bank
; switches to the bank in b
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,b
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ld bc,.Return
	push bc
	jp [hl]
.Return
	pop bc
	ld a,b
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

; displays yes/no choice
; yes -> set carry
YesNoChoice:: ; 35ec (0:35ec)
	call SaveScreenTilesToBuffer1
	call InitYesNoTextBoxParameters
	jr DisplayYesNoChoice

Func_35f4:: ; 35f4 (0:35f4)
	ld a, $14
	ld [wd125], a
	call InitYesNoTextBoxParameters
	jp DisplayTextBoxID

InitYesNoTextBoxParameters:: ; 35ff (0:35ff)
	xor a
	ld [wd12c], a
	FuncCoord 14, 7
	ld hl, Coord
	ld bc, $80f
	ret

YesNoChoicePokeCenter:: ; 360a (0:360a)
	call SaveScreenTilesToBuffer1
	ld a, $6
	ld [wd12c], a
	FuncCoord 11, 6
	ld hl, Coord
	ld bc, $80c
	jr DisplayYesNoChoice

Func_361a:: ; 361a (0:361a)
	call SaveScreenTilesToBuffer1
	ld a, $3
	ld [wd12c], a
	FuncCoord 12, 7
	ld hl, Coord
	ld bc, $080d
DisplayYesNoChoice:: ; 3628 (0:3628)
	ld a, $14
	ld [wd125], a
	call DisplayTextBoxID
	jp LoadScreenTilesFromBuffer1

; calculates the difference |a-b|, setting carry flag if a<b
CalcDifference:: ; 3633 (0:3633)
	sub b
	ret nc
	cpl
	add $1
	scf
	ret

MoveSprite:: ; 363a (0:363a)
; move the sprite [$FF8C] with the movement pointed to by de
; actually only copies the movement data to wcc5b for later
	call SetSpriteMovementBytesToFF
MoveSprite_:: ; 363d (0:363d)
	push hl
	push bc
	call GetSpriteMovementByte1Pointer
	xor a
	ld [hl],a
	ld hl,wcc5b
	ld c,0

.loop
	ld a,[de]
	ld [hli],a
	inc de
	inc c
	cp a,$FF ; have we reached the end of the movement data?
	jr nz,.loop

	ld a,c
	ld [wcf0f],a ; number of steps taken

	pop bc
	ld hl,wd730
	set 0,[hl]
	pop hl
	xor a
	ld [wcd3b],a
	ld [wccd3],a
	dec a
	ld [wJoyIgnore],a
	ld [wcd3a],a
	ret

Func_366b:: ; 366b (0:366b)
	push hl
	ld hl, $ffe7
	xor a
	ld [hld], a
	ld a, [hld]
	and a
	jr z, .asm_367e
	ld a, [hli]
.asm_3676
	sub [hl]
	jr c, .asm_367e
	inc hl
	inc [hl]
	dec hl
	jr .asm_3676
.asm_367e
	pop hl
	ret

; copies the tile patterns for letters and numbers into VRAM
LoadFontTilePatterns:: ; 3680 (0:3680)
	ld a,[rLCDC]
	bit 7,a ; is the LCD enabled?
	jr nz,.lcdEnabled
.lcdDisabled
	ld hl,FontGraphics
	ld de,vFont
	ld bc,$400
	ld a,BANK(FontGraphics)
	jp FarCopyDataDouble ; if LCD is off, transfer all at once
.lcdEnabled
	ld de,FontGraphics
	ld hl,vFont
	ld bc,(BANK(FontGraphics) << 8 | $80)
	jp CopyVideoDataDouble ; if LCD is on, transfer during V-blank

; copies the text box tile patterns into VRAM
LoadTextBoxTilePatterns:: ; 36a0 (0:36a0)
	ld a,[rLCDC]
	bit 7,a ; is the LCD enabled?
	jr nz,.lcdEnabled
.lcdDisabled
	ld hl,TextBoxGraphics
	ld de,vChars2 + $600
	ld bc,$200
	ld a,BANK(TextBoxGraphics)
	jp FarCopyData2 ; if LCD is off, transfer all at once
.lcdEnabled
	ld de,TextBoxGraphics
	ld hl,vChars2 + $600
	ld bc,(BANK(TextBoxGraphics) << 8 | $20)
	jp CopyVideoData ; if LCD is on, transfer during V-blank

; copies HP bar and status display tile patterns into VRAM
LoadHpBarAndStatusTilePatterns:: ; 36c0 (0:36c0)
	ld a,[rLCDC]
	bit 7,a ; is the LCD enabled?
	jr nz,.lcdEnabled
.lcdDisabled
	ld hl,HpBarAndStatusGraphics
	ld de,vChars2 + $620
	ld bc,$1e0
	ld a,BANK(HpBarAndStatusGraphics)
	jp FarCopyData2 ; if LCD is off, transfer all at once
.lcdEnabled
	ld de,HpBarAndStatusGraphics
	ld hl,vChars2 + $620
	ld bc,(BANK(HpBarAndStatusGraphics) << 8 | $1e)
	jp CopyVideoData ; if LCD is on, transfer during V-blank

;Fills memory range with the specified byte.
;input registers a = fill_byte, bc = length, hl = address
FillMemory:: ; 36e0 (0:36e0)
	push de
	ld d, a
.loop
	ld a, d
	ldi [hl], a
	dec bc
	ld a, b
	or c
	jr nz, .loop
	pop de
	ret

; loads sprite that de points to
; bank of sprite is given in a
UncompressSpriteFromDE:: ; 36eb (0:36eb)
	ld hl, W_SPRITEINPUTPTR
	ld [hl], e
	inc hl
	ld [hl], d
	jp UncompressSpriteData

SaveScreenTilesToBuffer2:: ; 36f4 (0:36f4)
	ld hl, wTileMap
	ld de, wTileMapBackup2
	ld bc, $168
	call CopyData
	ret

LoadScreenTilesFromBuffer2:: ; 3701 (0:3701)
	call LoadScreenTilesFromBuffer2DisableBGTransfer
	ld a, $1
	ld [H_AUTOBGTRANSFERENABLED], a ; $ffba
	ret

; loads screen tiles stored in wTileMapBackup2 but leaves H_AUTOBGTRANSFERENABLED disabled
LoadScreenTilesFromBuffer2DisableBGTransfer:: ; 3709 (0:3709)
	xor a
	ld [H_AUTOBGTRANSFERENABLED], a ; $ffba
	ld hl, wTileMapBackup2
	ld de, wTileMap
	ld bc, $168
	call CopyData
	ret

SaveScreenTilesToBuffer1:: ; 3719 (0:3719)
	ld hl, wTileMap
	ld de, wTileMapBackup
	ld bc, $168
	jp CopyData

LoadScreenTilesFromBuffer1:: ; 3725 (0:3725)
	xor a
	ld [H_AUTOBGTRANSFERENABLED], a ; $ffba
	ld hl, wTileMapBackup
	ld de, wTileMap
	ld bc, $168
	call CopyData
	ld a, $1
	ld [H_AUTOBGTRANSFERENABLED], a ; $ffba
	ret

DelayFrames:: ; 3739 (0:3739)
; wait n frames, where n is the value in c
	call DelayFrame
	dec c
	jr nz,DelayFrames
	ret

PlaySoundWaitForCurrent:: ; 3740 (0:3740)
	push af
	call WaitForSoundToFinish
	pop af
	jp PlaySound

; Wait for sound to finish playing
WaitForSoundToFinish:: ; 3748 (0:3748)
	ld a, [wd083]
	and $80
	ret nz
	push hl
.asm_374f
	ld hl, wc02a
	xor a
	or [hl]
	inc hl
	or [hl]
	inc hl
	inc hl
	or [hl]
	jr nz, .asm_374f
	pop hl
	ret

NamePointers:: ; 375d (0:375d)
	dw MonsterNames
	dw MoveNames
	dw UnusedNames
	dw ItemNames
	dw wPartyMonOT ; player's OT names list
	dw wEnemyMonOT ; enemy's OT names list
	dw TrainerNames

GetName:: ; 376b (0:376b)
; arguments:
; [wd0b5] = which name
; [wd0b6] = which list (W_LISTTYPE)
; [wPredefBank] = bank of list
;
; returns pointer to name in de
	ld a,[wd0b5]
	ld [wd11e],a
	cp a,$C4        ;it's TM/HM
	jp nc,GetMachineName
	ld a,[H_LOADEDROMBANK]
	push af
	push hl
	push bc
	push de
	ld a,[W_LISTTYPE]    ;List3759_entrySelector
	dec a
	jr nz,.otherEntries
	;1 = MON_NAMES
	call GetMonName
	ld hl,11
	add hl,de
	ld e,l
	ld d,h
	jr .gotPtr
.otherEntries ; $378d
	;2-7 = OTHER ENTRIES
	ld a,[wPredefBank]
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ld a,[W_LISTTYPE]    ;VariousNames' entryID
	dec a
	add a
	ld d,0
	ld e,a
	jr nc,.skip
	inc d
.skip ; $37a0
	ld hl,NamePointers
	add hl,de
	ld a,[hli]
	ld [$ff96],a
	ld a,[hl]
	ld [$ff95],a
	ld a,[$ff95]
	ld h,a
	ld a,[$ff96]
	ld l,a
	ld a,[wd0b5]
	ld b,a
	ld c,0
.nextName
	ld d,h
	ld e,l
.nextChar
	ld a,[hli]
	cp a, "@"
	jr nz,.nextChar
	inc c           ;entry counter
	ld a,b          ;wanted entry
	cp c
	jr nz,.nextName
	ld h,d
	ld l,e
	ld de,wcd6d
	ld bc,$0014
	call CopyData
.gotPtr ; $37cd
	ld a,e
	ld [wcf8d],a
	ld a,d
	ld [wcf8e],a
	pop de
	pop bc
	pop hl
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	ret

GetItemPrice:: ; 37df (0:37df)
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, [wListMenuID] ; wListMenuID
	cp $1
	ld a, $1 ; hardcoded Bank
	jr nz, .asm_37ed
	ld a, $f ; hardcoded Bank
.asm_37ed
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ld hl, wcf8f
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld a, [wcf91]
	cp HM_01
	jr nc, .asm_3812
	ld bc, $3
.asm_3802
	add hl, bc
	dec a
	jr nz, .asm_3802
	dec hl
	ld a, [hld]
	ld [$ff8d], a
	ld a, [hld]
	ld [H_DOWNARROWBLINKCNT2], a ; $ff8c
	ld a, [hl]
	ld [H_DOWNARROWBLINKCNT1], a ; $ff8b
	jr .asm_381c
.asm_3812
	ld a, Bank(GetMachinePrice)
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	call GetMachinePrice
.asm_381c
	ld de, H_DOWNARROWBLINKCNT1 ; $ff8b
	pop af
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ret

; copies a string from [de] to [wcf4b]
CopyStringToCF4B:: ; 3826 (0:3826)
	ld hl, wcf4b
	; fall through

; copies a string from [de] to [hl]
CopyString:: ; 3829 (0:3829)
	ld a, [de]
	inc de
	ld [hli], a
	cp "@"
	jr nz, CopyString
	ret

; this function is used when lower button sensitivity is wanted (e.g. menus)
; OUTPUT: [$ffb5] = pressed buttons in usual format
; there are two flags that control its functionality, [$ffb6] and [$ffb7]
; there are esentially three modes of operation
; 1. Get newly pressed buttons only
;    ([$ffb7] == 0, [$ffb6] == any)
;    Just copies [hJoyPressed] to [$ffb5].
; 2. Get currently pressed buttons at low sample rate with delay
;    ([$ffb7] == 1, [$ffb6] != 0)
;    If the user holds down buttons for more than half a second,
;    report buttons as being pressed up to 12 times per second thereafter.
;    If the user holds down buttons for less than half a second,
;    report only one button press.
; 3. Same as 2, but report no buttons as pressed if A or B is held down.
;    ([$ffb7] == 1, [$ffb6] == 0)
JoypadLowSensitivity:: ; 3831 (0:3831)
	call Joypad
	ld a,[$ffb7] ; flag
	and a ; get all currently pressed buttons or only newly pressed buttons?
	ld a,[hJoyPressed] ; newly pressed buttons
	jr z,.storeButtonState
	ld a,[hJoyHeld] ; all currently pressed buttons
.storeButtonState
	ld [$ffb5],a
	ld a,[hJoyPressed] ; newly pressed buttons
	and a ; have any buttons been newly pressed since last check?
	jr z,.noNewlyPressedButtons
.newlyPressedButtons
	ld a,30 ; half a second delay
	ld [H_FRAMECOUNTER],a
	ret
.noNewlyPressedButtons
	ld a,[H_FRAMECOUNTER]
	and a ; is the delay over?
	jr z,.delayOver
.delayNotOver
	xor a
	ld [$ffb5],a ; report no buttons as pressed
	ret
.delayOver
; if [$ffb6] = 0 and A or B is pressed, report no buttons as pressed
	ld a,[hJoyHeld]
	and a,%00000011 ; A and B buttons
	jr z,.setShortDelay
	ld a,[$ffb6] ; flag
	and a
	jr nz,.setShortDelay
	xor a
	ld [$ffb5],a
.setShortDelay
	ld a,5 ; 1/12 of a second delay
	ld [H_FRAMECOUNTER],a
	ret

WaitForTextScrollButtonPress:: ; 3865 (0:3865)
	ld a, [H_DOWNARROWBLINKCNT1] ; $ff8b
	push af
	ld a, [H_DOWNARROWBLINKCNT2] ; $ff8c
	push af
	xor a
	ld [H_DOWNARROWBLINKCNT1], a ; $ff8b
	ld a, $6
	ld [H_DOWNARROWBLINKCNT2], a ; $ff8c
.asm_3872
	push hl
	ld a, [wd09b]
	and a
	jr z, .asm_387c
	call Func_716c6
.asm_387c
	FuncCoord 18, 16
	ld hl, Coord
	call HandleDownArrowBlinkTiming
	pop hl
	call JoypadLowSensitivity
	predef Func_5a5f
	ld a, [$ffb5]
	and A_BUTTON | B_BUTTON
	jr z, .asm_3872
	pop af
	ld [H_DOWNARROWBLINKCNT2], a ; $ff8c
	pop af
	ld [H_DOWNARROWBLINKCNT1], a ; $ff8b
	ret

; (unlass in link battle) waits for A or B being pressed and outputs the scrolling sound effect
ManualTextScroll:: ; 3898 (0:3898)
	ld a, [W_ISLINKBATTLE] ; W_ISLINKBATTLE
	cp $4
	jr z, .inLinkBattle
	call WaitForTextScrollButtonPress
	ld a, (SFX_02_40 - SFX_Headers_02) / 3
	jp PlaySound
.inLinkBattle
	ld c, $41
	jp DelayFrames

; function to do multiplication
; all values are big endian
; INPUT
; FF96-FF98 =  multiplicand
; FF99 = multiplier
; OUTPUT
; FF95-FF98 = product
Multiply:: ; 38ac (0:38ac)
	push hl
	push bc
	callab _Multiply
	pop bc
	pop hl
	ret

; function to do division
; all values are big endian
; INPUT
; FF95-FF98 = dividend
; FF99 = divisor
; b = number of bytes in the dividend (starting from FF95)
; OUTPUT
; FF95-FF98 = quotient
; FF99 = remainder
Divide:: ; 38b9 (0:38b9)
	push hl
	push de
	push bc
	ld a,[H_LOADEDROMBANK]
	push af
	ld a,Bank(_Divide)
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	call _Divide
	pop af
	ld [H_LOADEDROMBANK],a
	ld [$2000],a
	pop bc
	pop de
	pop hl
	ret

; This function is used to wait a short period after printing a letter to the
; screen unless the player presses the A/B button or the delay is turned off
; through the [wd730] or [wd358] flags.
PrintLetterDelay:: ; 38d3 (0:38d3)
	ld a,[wd730]
	bit 6,a
	ret nz
	ld a,[wd358]
	bit 1,a
	ret z
	push hl
	push de
	push bc
	ld a,[wd358]
	bit 0,a
	jr z,.waitOneFrame
	ld a,[W_OPTIONS]
	and a,$0f
	ld [H_FRAMECOUNTER],a
	jr .checkButtons
.waitOneFrame
	ld a,1
	ld [H_FRAMECOUNTER],a
.checkButtons
	call Joypad
	ld a,[hJoyHeld]
.checkAButton
	bit 0,a ; is the A button pressed?
	jr z,.checkBButton
	jr .endWait
.checkBButton
	bit 1,a ; is the B button pressed?
	jr z,.buttonsNotPressed
.endWait
	call DelayFrame
	jr .done
.buttonsNotPressed ; if neither A nor B is pressed
	ld a,[H_FRAMECOUNTER]
	and a
	jr nz,.checkButtons
.done
	pop bc
	pop de
	pop hl
	ret

; Copies [hl, bc) to [de, bc - hl).
; In other words, the source data is from hl up to but not including bc,
; and the destination is de.
CopyDataUntil:: ; 3913 (0:3913)
	ld a,[hli]
	ld [de],a
	inc de
	ld a,h
	cp b
	jr nz,CopyDataUntil
	ld a,l
	cp c
	jr nz,CopyDataUntil
	ret

; Function to remove a pokemon from the party or the current box.
; wWhichPokemon determines the pokemon.
; [wcf95] == 0 specifies the party.
; [wcf95] != 0 specifies the current box.
RemovePokemon:: ; 391f (0:391f)
	ld hl, _RemovePokemon
	ld b, BANK(_RemovePokemon)
	jp Bankswitch

AddPartyMon:: ; 3927 (0:3927)
	push hl
	push de
	push bc
	callba _AddPartyMon
	pop bc
	pop de
	pop hl
	ret

; calculates all 5 stats of current mon and writes them to [de]
CalcStats:: ; 3936 (0:3936)
	ld c, $0
.statsLoop
	inc c
	call CalcStat
	ld a, [H_MULTIPLICAND+1]
	ld [de], a
	inc de
	ld a, [H_MULTIPLICAND+2]
	ld [de], a
	inc de
	ld a, c
	cp $5
	jr nz, .statsLoop
	ret

; calculates stat c of current mon
; c: stat to calc (HP=1,Atk=2,Def=3,Spd=4,Spc=5)
; b: consider stat exp?
; hl: base ptr to stat exp values ([hl + 2*c - 1] and [hl + 2*c])
CalcStat:: ; 394a (0:394a)
	push hl
	push de
	push bc
	ld a, b
	ld d, a
	push hl
	ld hl, W_MONHEADER
	ld b, $0
	add hl, bc
	ld a, [hl]          ; read base value of stat
	ld e, a
	pop hl
	push hl
	sla c
	ld a, d
	and a
	jr z, .statExpDone  ; consider stat exp?
	add hl, bc          ; skip to corresponding stat exp value
.statExpLoop            ; calculates ceil(Sqrt(stat exp)) in b
	xor a
	ld [H_MULTIPLICAND], a
	ld [H_MULTIPLICAND+1], a
	inc b               ; increment current stat exp bonus
	ld a, b
	cp $ff
	jr z, .statExpDone
	ld [H_MULTIPLICAND+2], a
	ld [H_MULTIPLIER], a
	call Multiply
	ld a, [hld]
	ld d, a
	ld a, [$ff98]
	sub d
	ld a, [hli]
	ld d, a
	ld a, [$ff97]
	sbc d               ; test if (current stat exp bonus)^2 < stat exp
	jr c, .statExpLoop
.statExpDone
	srl c
	pop hl
	push bc
	ld bc, $b           ; skip to stat IV values
	add hl, bc
	pop bc
	ld a, c
	cp $2
	jr z, .getAttackIV
	cp $3
	jr z, .getDefenseIV
	cp $4
	jr z, .getSpeedIV
	cp $5
	jr z, .getSpecialIV
.getHpIV
	push bc
	ld a, [hl]  ; Atk IV
	swap a
	and $1
	sla a
	sla a
	sla a
	ld b, a
	ld a, [hli] ; Def IV
	and $1
	sla a
	sla a
	add b
	ld b, a
	ld a, [hl] ; Spd IV
	swap a
	and $1
	sla a
	add b
	ld b, a
	ld a, [hl] ; Spc IV
	and $1
	add b      ; HP IV: LSB of the other 4 IVs
	pop bc
	jr .calcStatFromIV
.getAttackIV
	ld a, [hl]
	swap a
	and $f
	jr .calcStatFromIV
.getDefenseIV
	ld a, [hl]
	and $f
	jr .calcStatFromIV
.getSpeedIV
	inc hl
	ld a, [hl]
	swap a
	and $f
	jr .calcStatFromIV
.getSpecialIV
	inc hl
	ld a, [hl]
	and $f
.calcStatFromIV
	ld d, $0
	add e
	ld e, a
	jr nc, .noCarry
	inc d                     ; de = Base + IV
.noCarry
	sla e
	rl d                      ; de = (Base + IV) * 2
	srl b
	srl b                     ; b = ceil(Sqrt(stat exp)) / 4
	ld a, b
	add e
	jr nc, .noCarry2
	inc d                     ; da = (Base + IV) * 2 + ceil(Sqrt(stat exp)) / 4
.noCarry2
	ld [H_MULTIPLICAND+2], a
	ld a, d
	ld [H_MULTIPLICAND+1], a
	xor a
	ld [H_MULTIPLICAND], a
	ld a, [W_CURENEMYLVL] ; W_CURENEMYLVL
	ld [H_MULTIPLIER], a
	call Multiply            ; ((Base + IV) * 2 + ceil(Sqrt(stat exp)) / 4) * Level
	ld a, [H_MULTIPLICAND]
	ld [H_DIVIDEND], a
	ld a, [H_MULTIPLICAND+1]
	ld [H_DIVIDEND+1], a
	ld a, [H_MULTIPLICAND+2]
	ld [H_DIVIDEND+2], a
	ld a, $64
	ld [H_DIVISOR], a
	ld a, $3
	ld b, a
	call Divide             ; (((Base + IV) * 2 + ceil(Sqrt(stat exp)) / 4) * Level) / 100
	ld a, c
	cp $1
	ld a, $5
	jr nz, .notHPStat
	ld a, [W_CURENEMYLVL] ; W_CURENEMYLVL
	ld b, a
	ld a, [H_MULTIPLICAND+2]
	add b
	ld [H_MULTIPLICAND+2], a
	jr nc, .noCarry3
	ld a, [H_MULTIPLICAND+1]
	inc a
	ld [H_MULTIPLICAND+1], a ; HP: (((Base + IV) * 2 + ceil(Sqrt(stat exp)) / 4) * Level) / 100 + Level
.noCarry3
	ld a, $a
.notHPStat
	ld b, a
	ld a, [H_MULTIPLICAND+2]
	add b
	ld [H_MULTIPLICAND+2], a
	jr nc, .noCarry4
	ld a, [H_MULTIPLICAND+1]
	inc a                    ; non-HP: (((Base + IV) * 2 + ceil(Sqrt(stat exp)) / 4) * Level) / 100 + 5
	ld [H_MULTIPLICAND+1], a ; HP: (((Base + IV) * 2 + ceil(Sqrt(stat exp)) / 4) * Level) / 100 + Level + 10
.noCarry4
	ld a, [H_MULTIPLICAND+1] ; check for overflow (>999)
	cp $4
	jr nc, .overflow
	cp $3
	jr c, .noOverflow
	ld a, [H_MULTIPLICAND+2]
	cp $e8
	jr c, .noOverflow
.overflow
	ld a, $3                 ; overflow: cap at 999
	ld [H_MULTIPLICAND+1], a
	ld a, $e7
	ld [H_MULTIPLICAND+2], a
.noOverflow
	pop bc
	pop de
	pop hl
	ret

AddEnemyMonToPlayerParty:: ; 3a53 (0:3a53)
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, BANK(_AddEnemyMonToPlayerParty)
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	call _AddEnemyMonToPlayerParty
	pop bc
	ld a, b
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ret

Func_3a68:: ; 3a68 (0:3a68)
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, BANK(Func_f51e)
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	call Func_f51e
	pop bc
	ld a, b
	ld [H_LOADEDROMBANK], a
	ld [$2000], a
	ret

; skips a text entries, each of size $b (like trainer name, OT name, rival name, ...)
; hl: base pointer, will be incremented by $b * a
SkipFixedLengthTextEntries:: ; 3a7d (0:3a7d)
	and a
	ret z
	ld bc, $b
.skipLoop
	add hl, bc
	dec a
	jr nz, .skipLoop
	ret

AddNTimes:: ; 3a87 (0:3a87)
; add bc to hl a times
	and a
	ret z
.loop
	add hl,bc
	dec a
	jr nz,.loop
	ret

; Compare strings, c bytes in length, at de and hl.
; Often used to compare big endian numbers in battle calculations.
StringCmp:: ; 3a8e (0:3a8e)
	ld a,[de]
	cp [hl]
	ret nz
	inc de
	inc hl
	dec c
	jr nz,StringCmp
	ret

; INPUT:
; a = oam block index (each block is 4 oam entries)
; b = Y coordinate of upper left corner of sprite
; c = X coordinate of upper left corner of sprite
; de = base address of 4 tile number and attribute pairs
WriteOAMBlock:: ; 3a97 (0:3a97)
	ld h,wOAMBuffer / $100
	swap a ; multiply by 16
	ld l,a
	call .writeOneEntry ; upper left
	push bc
	ld a,8
	add c
	ld c,a
	call .writeOneEntry ; upper right
	pop bc
	ld a,8
	add b
	ld b,a
	call .writeOneEntry ; lower left
	ld a,8
	add c
	ld c,a
	                      ; lower right
.writeOneEntry
	ld [hl],b ; Y coordinate
	inc hl
	ld [hl],c ; X coordinate
	inc hl
	ld a,[de] ; tile number
	inc de
	ld [hli],a
	ld a,[de] ; attribute
	inc de
	ld [hli],a
	ret

HandleMenuInput:: ; 3abe (0:3abe)
	xor a
	ld [wd09b],a

HandleMenuInputPokemonSelection:: ; 3ac2 (0:3ac2)
	ld a,[H_DOWNARROWBLINKCNT1]
	push af
	ld a,[H_DOWNARROWBLINKCNT2]
	push af ; save existing values on stack
	xor a
	ld [H_DOWNARROWBLINKCNT1],a ; blinking down arrow timing value 1
	ld a,$06
	ld [H_DOWNARROWBLINKCNT2],a ; blinking down arrow timing value 2
.loop1
	xor a
	ld [W_SUBANIMTRANSFORM],a ; counter for pokemon shaking animation
	call PlaceMenuCursor
	call Delay3
.loop2
	push hl
	ld a,[wd09b]
	and a ; is it a pokemon selection menu?
	jr z,.getJoypadState
	callba AnimatePartyMon ; shake mini sprite of selected pokemon
.getJoypadState
	pop hl
	call JoypadLowSensitivity
	ld a,[$ffb5]
	and a ; was a key pressed?
	jr nz,.keyPressed
	push hl
	FuncCoord 18,11 ; coordinates of blinking down arrow in some menus
	ld hl,Coord
	call HandleDownArrowBlinkTiming ; blink down arrow (if any)
	pop hl
	ld a,[wMenuJoypadPollCount]
	dec a
	jr z,.giveUpWaiting
	jr .loop2
.giveUpWaiting
; if a key wasn't pressed within the specified number of checks
	pop af
	ld [H_DOWNARROWBLINKCNT2],a
	pop af
	ld [H_DOWNARROWBLINKCNT1],a ; restore previous values
	xor a
	ld [wMenuWrappingEnabled],a ; disable menu wrapping
	ret
.keyPressed
	xor a
	ld [wcc4b],a
	ld a,[$ffb5]
	ld b,a
	bit 6,a ; pressed Up key?
	jr z,.checkIfDownPressed
.upPressed
	ld a,[wCurrentMenuItem] ; selected menu item
	and a ; already at the top of the menu?
	jr z,.alreadyAtTop
.notAtTop
	dec a
	ld [wCurrentMenuItem],a ; move selected menu item up one space
	jr .checkOtherKeys
.alreadyAtTop
	ld a,[wMenuWrappingEnabled]
	and a ; is wrapping around enabled?
	jr z,.noWrappingAround
	ld a,[wMaxMenuItem]
	ld [wCurrentMenuItem],a ; wrap to the bottom of the menu
	jr .checkOtherKeys
.checkIfDownPressed
	bit 7,a
	jr z,.checkOtherKeys
.downPressed
	ld a,[wCurrentMenuItem]
	inc a
	ld c,a
	ld a,[wMaxMenuItem]
	cp c
	jr nc,.notAtBottom
.alreadyAtBottom
	ld a,[wMenuWrappingEnabled]
	and a ; is wrapping around enabled?
	jr z,.noWrappingAround
	ld c,$00 ; wrap from bottom to top
.notAtBottom
	ld a,c
	ld [wCurrentMenuItem],a
.checkOtherKeys
	ld a,[wMenuWatchedKeys]
	and b ; does the menu care about any of the pressed keys?
	jp z,.loop1
.checkIfAButtonOrBButtonPressed
	ld a,[$ffb5]
	and a,%00000011 ; pressed A button or B button?
	jr z,.skipPlayingSound
.AButtonOrBButtonPressed
	push hl
	ld hl,wFlags_0xcd60
	bit 5,[hl]
	pop hl
	jr nz,.skipPlayingSound
	ld a,(SFX_02_40 - SFX_Headers_02) / 3
	call PlaySound ; play sound
.skipPlayingSound
	pop af
	ld [H_DOWNARROWBLINKCNT2],a
	pop af
	ld [H_DOWNARROWBLINKCNT1],a ; restore previous values
	xor a
	ld [wMenuWrappingEnabled],a ; disable menu wrapping
	ld a,[$ffb5]
	ret
.noWrappingAround
	ld a,[wcc37]
	and a ; should we return if the user tried to go past the top or bottom?
	jr z,.checkOtherKeys
	jr .checkIfAButtonOrBButtonPressed

PlaceMenuCursor:: ; 3b7c (0:3b7c)
	ld a,[wTopMenuItemY]
	and a ; is the y coordinate 0?
	jr z,.adjustForXCoord
	ld hl,wTileMap
	ld bc,20 ; screen width
.topMenuItemLoop
	add hl,bc
	dec a
	jr nz,.topMenuItemLoop
.adjustForXCoord
	ld a,[wTopMenuItemX]
	ld b,$00
	ld c,a
	add hl,bc
	push hl
	ld a,[wLastMenuItem]
	and a ; was the previous menu id 0?
	jr z,.checkForArrow1
	push af
	ld a,[$fff6]
	bit 1,a ; is the menu double spaced?
	jr z,.doubleSpaced1
	ld bc,20
	jr .getOldMenuItemScreenPosition
.doubleSpaced1
	ld bc,40
.getOldMenuItemScreenPosition
	pop af
.oldMenuItemLoop
	add hl,bc
	dec a
	jr nz,.oldMenuItemLoop
.checkForArrow1
	ld a,[hl]
	cp a,"▶" ; was an arrow next to the previously selected menu item?
	jr nz,.skipClearingArrow
.clearArrow
	ld a,[wTileBehindCursor]
	ld [hl],a
.skipClearingArrow
	pop hl
	ld a,[wCurrentMenuItem]
	and a
	jr z,.checkForArrow2
	push af
	ld a,[$fff6]
	bit 1,a ; is the menu double spaced?
	jr z,.doubleSpaced2
	ld bc,20
	jr .getCurrentMenuItemScreenPosition
.doubleSpaced2
	ld bc,40
.getCurrentMenuItemScreenPosition
	pop af
.currentMenuItemLoop
	add hl,bc
	dec a
	jr nz,.currentMenuItemLoop
.checkForArrow2
	ld a,[hl]
	cp a,"▶" ; has the right arrow already been placed?
	jr z,.skipSavingTile ; if so, don't lose the saved tile
	ld [wTileBehindCursor],a ; save tile before overwriting with right arrow
.skipSavingTile
	ld a,"▶" ; place right arrow
	ld [hl],a
	ld a,l
	ld [wMenuCursorLocation],a
	ld a,h
	ld [wMenuCursorLocation + 1],a
	ld a,[wCurrentMenuItem]
	ld [wLastMenuItem],a
	ret

; This is used to mark a menu cursor other than the one currently being
; manipulated. In the case of submenus, this is used to show the location of
; the menu cursor in the parent menu. In the case of swapping items in list,
; this is used to mark the item that was first chosen to be swapped.
PlaceUnfilledArrowMenuCursor:: ; 3bec (0:3bec)
	ld b,a
	ld a,[wMenuCursorLocation]
	ld l,a
	ld a,[wMenuCursorLocation + 1]
	ld h,a
	ld [hl],$ec ; outline of right arrow
	ld a,b
	ret

; Replaces the menu cursor with a blank space.
EraseMenuCursor:: ; 3bf9 (0:3bf9)
	ld a,[wMenuCursorLocation]
	ld l,a
	ld a,[wMenuCursorLocation + 1]
	ld h,a
	ld [hl]," "
	ret

; This toggles a blinking down arrow at hl on and off after a delay has passed.
; This is often called even when no blinking is occurring.
; The reason is that most functions that call this initialize H_DOWNARROWBLINKCNT1 to 0.
; The effect is that if the tile at hl is initialized with a down arrow,
; this function will toggle that down arrow on and off, but if the tile isn't
; initliazed with a down arrow, this function does nothing.
; That allows this to be called without worrying about if a down arrow should
; be blinking.
HandleDownArrowBlinkTiming:: ; 3c04 (0:3c04)
	ld a,[hl]
	ld b,a
	ld a,$ee ; down arrow
	cp b
	jr nz,.downArrowOff
.downArrowOn
	ld a,[H_DOWNARROWBLINKCNT1]
	dec a
	ld [H_DOWNARROWBLINKCNT1],a
	ret nz
	ld a,[H_DOWNARROWBLINKCNT2]
	dec a
	ld [H_DOWNARROWBLINKCNT2],a
	ret nz
	ld a," "
	ld [hl],a
	ld a,$ff
	ld [H_DOWNARROWBLINKCNT1],a
	ld a,$06
	ld [H_DOWNARROWBLINKCNT2],a
	ret
.downArrowOff
	ld a,[H_DOWNARROWBLINKCNT1]
	and a
	ret z
	dec a
	ld [H_DOWNARROWBLINKCNT1],a
	ret nz
	dec a
	ld [H_DOWNARROWBLINKCNT1],a
	ld a,[H_DOWNARROWBLINKCNT2]
	dec a
	ld [H_DOWNARROWBLINKCNT2],a
	ret nz
	ld a,$06
	ld [H_DOWNARROWBLINKCNT2],a
	ld a,$ee ; down arrow
	ld [hl],a
	ret

; The following code either enables or disables the automatic drawing of
; text boxes by DisplayTextID. Both functions cause DisplayTextID to wait
; for a button press after displaying text (unless [wcc47] is set).

EnableAutoTextBoxDrawing:: ; 3c3c (0:3c3c)
	xor a
	jr AutoTextBoxDrawingCommon

DisableAutoTextBoxDrawing:: ; 3c3f (0:3c3f)
	ld a,$01

AutoTextBoxDrawingCommon:: ; 3c41 (0:3c41)
	ld [wcf0c],a ; control text box drawing
	xor a
	ld [wcc3c],a ; make DisplayTextID wait for button press
	ret

PrintText:: ; 3c49 (0:3c49)
; given a pointer in hl, print the text there
	push hl
	ld a,1
	ld [wd125],a
	call DisplayTextBoxID
	call UpdateSprites
	call Delay3
	pop hl
Func_3c59:: ; 3c59 (0:3c59)
	FuncCoord 1,14
	ld bc,Coord
	jp TextCommandProcessor

; converts a big-endian binary number into decimal and prints it
; INPUT:
; b = flags and number of bytes
; bit 7: if set, print leading zeroes
;        if unset, do not print leading zeroes
; bit 6: if set, left-align the string (do not pad empty digits with spaces)
;        if unset, right-align the string
; bits 4-5: unused
; bits 0-3: number of bytes (only 1 - 3 bytes supported)
; c = number of decimal digits
; de = address of the number (big-endian)
PrintNumber:: ; 3c5f (0:3c5f)
	push bc
	xor a
	ld [H_PASTLEADINGZEROES],a
	ld [H_NUMTOPRINT],a
	ld [H_NUMTOPRINT + 1],a
	ld a,b
	and a,%00001111
	cp a,1
	jr z,.oneByte
	cp a,2
	jr z,.twoBytes
.threeBytes
	ld a,[de]
	ld [H_NUMTOPRINT],a
	inc de
	ld a,[de]
	ld [H_NUMTOPRINT + 1],a
	inc de
	ld a,[de]
	ld [H_NUMTOPRINT + 2],a
	jr .checkNumDigits
.twoBytes
	ld a,[de]
	ld [H_NUMTOPRINT + 1],a
	inc de
	ld a,[de]
	ld [H_NUMTOPRINT + 2],a
	jr .checkNumDigits
.oneByte
	ld a,[de]
	ld [H_NUMTOPRINT + 2],a
.checkNumDigits
	push de
	ld d,b
	ld a,c
	ld b,a
	xor a
	ld c,a
	ld a,b ; a = number of decimal digits
	cp a,2
	jr z,.tensPlace
	cp a,3
	jr z,.hundredsPlace
	cp a,4
	jr z,.thousandsPlace
	cp a,5
	jr z,.tenThousandsPlace
	cp a,6
	jr z,.hundredThousandsPlace
.millionsPlace
	ld a,1000000 >> 16
	ld [H_POWEROFTEN],a
	ld a,(1000000 >> 8) & $FF
	ld [H_POWEROFTEN + 1],a
	ld a,1000000 & $FF
	ld [H_POWEROFTEN + 2],a
	call PrintNumber_PrintDigit
	call PrintNumber_AdvancePointer
.hundredThousandsPlace
	ld a,100000 >> 16
	ld [H_POWEROFTEN],a
	ld a,(100000 >> 8) & $FF
	ld [H_POWEROFTEN + 1],a
	ld a,100000 & $FF
	ld [H_POWEROFTEN + 2],a
	call PrintNumber_PrintDigit
	call PrintNumber_AdvancePointer
.tenThousandsPlace
	xor a
	ld [H_POWEROFTEN],a
	ld a,10000 >> 8
	ld [H_POWEROFTEN + 1],a
	ld a,10000 & $FF
	ld [H_POWEROFTEN + 2],a
	call PrintNumber_PrintDigit
	call PrintNumber_AdvancePointer
.thousandsPlace
	xor a
	ld [H_POWEROFTEN],a
	ld a,1000 >> 8
	ld [H_POWEROFTEN + 1],a
	ld a,1000 & $FF
	ld [H_POWEROFTEN + 2],a
	call PrintNumber_PrintDigit
	call PrintNumber_AdvancePointer
.hundredsPlace
	xor a
	ld [H_POWEROFTEN],a
	xor a
	ld [H_POWEROFTEN + 1],a
	ld a,100
	ld [H_POWEROFTEN + 2],a
	call PrintNumber_PrintDigit
	call PrintNumber_AdvancePointer
.tensPlace
	ld c,00
	ld a,[H_NUMTOPRINT + 2]
.loop
	cp a,10
	jr c,.underflow
	sub a,10
	inc c
	jr .loop
.underflow
	ld b,a
	ld a,[H_PASTLEADINGZEROES]
	or c
	ld [H_PASTLEADINGZEROES],a
	jr nz,.pastLeadingZeroes
	call PrintNumber_PrintLeadingZero
	jr .advancePointer
.pastLeadingZeroes
	ld a,"0"
	add c
	ld [hl],a
.advancePointer
	call PrintNumber_AdvancePointer
.onesPlace
	ld a,"0"
	add b
	ld [hli],a
	pop de
	dec de
	pop bc
	ret

; prints a decimal digit
; This works by repeatedely subtracting a power of ten until the number becomes negative.
; The number of subtractions it took in order to make the number negative is the digit for the current number place.
; The last value that the number had before becoming negative is kept as the new value of the number.
; A more succinct description is that the number is divided by a power of ten
; and the quotient becomes the digit while the remainder is stored as the new value of the number.
PrintNumber_PrintDigit:: ; 3d25 (0:3d25)
	ld c,0 ; counts number of loop iterations to determine the decimal digit
.loop
	ld a,[H_POWEROFTEN]
	ld b,a
	ld a,[H_NUMTOPRINT]
	ld [H_SAVEDNUMTOPRINT],a
	cp b
	jr c,.underflow0
	sub b
	ld [H_NUMTOPRINT],a
	ld a,[H_POWEROFTEN + 1]
	ld b,a
	ld a,[H_NUMTOPRINT + 1]
	ld [H_SAVEDNUMTOPRINT + 1],a
	cp b
	jr nc,.noBorrowForByte1
.byte1BorrowFromByte0
	ld a,[H_NUMTOPRINT]
	or a,0
	jr z,.underflow1
	dec a
	ld [H_NUMTOPRINT],a
	ld a,[H_NUMTOPRINT + 1]
.noBorrowForByte1
	sub b
	ld [H_NUMTOPRINT + 1],a
	ld a,[H_POWEROFTEN + 2]
	ld b,a
	ld a,[H_NUMTOPRINT + 2]
	ld [H_SAVEDNUMTOPRINT + 2],a
	cp b
	jr nc,.noBorrowForByte2
.byte2BorrowFromByte1
	ld a,[H_NUMTOPRINT + 1]
	and a
	jr nz,.finishByte2BorrowFromByte1
.byte2BorrowFromByte0
	ld a,[H_NUMTOPRINT]
	and a
	jr z,.underflow2
	dec a
	ld [H_NUMTOPRINT],a
	xor a
.finishByte2BorrowFromByte1
	dec a
	ld [H_NUMTOPRINT + 1],a
	ld a,[H_NUMTOPRINT + 2]
.noBorrowForByte2
	sub b
	ld [H_NUMTOPRINT + 2],a
	inc c
	jr .loop
.underflow2
	ld a,[H_SAVEDNUMTOPRINT + 1]
	ld [H_NUMTOPRINT + 1],a
.underflow1
	ld a,[H_SAVEDNUMTOPRINT]
	ld [H_NUMTOPRINT],a
.underflow0
	ld a,[H_PASTLEADINGZEROES]
	or c
	jr z,PrintNumber_PrintLeadingZero
	ld a,"0"
	add c
	ld [hl],a
	ld [H_PASTLEADINGZEROES],a
	ret

; prints a leading zero unless they are turned off in the flags
PrintNumber_PrintLeadingZero:: ; 3d83 (0:3d83)
	bit 7,d ; print leading zeroes?
	ret z
	ld [hl],"0"
	ret

; increments the pointer unless leading zeroes are not being printed,
; the number is left-aligned, and no nonzero digits have been printed yet
PrintNumber_AdvancePointer:: ; 3d89 (0:3d89)
	bit 7,d ; print leading zeroes?
	jr nz,.incrementPointer
	bit 6,d ; left alignment or right alignment?
	jr z,.incrementPointer
	ld a,[H_PASTLEADINGZEROES]
	and a
	ret z
.incrementPointer
	inc hl
	ret

; calls a function from a table of function pointers
; INPUT:
; a = index within table
; hl = address of function pointer table
CallFunctionInTable:: ; 3d97 (0:3d97)
	push hl
	push de
	push bc
	add a
	ld d,0
	ld e,a
	add hl,de
	ld a,[hli]
	ld h,[hl]
	ld l,a
	ld de,.returnAddress
	push de
	jp [hl]
.returnAddress
	pop bc
	pop de
	pop hl
	ret


IsInArray::
; Search an array at hl for the value in a.
; Entry size is de bytes.
; Return count b and carry if found.
	ld b, 0

IsInRestOfArray::
	ld c, a
.loop
	ld a, [hl]
	cp -1
	jr z, .notfound
	cp c
	jr z, .found
	inc b
	add hl, de
	jr .loop

.notfound
	and a
	ret

.found
	scf
	ret


Func_3dbe:: ; 3dbe (0:3dbe)
	call ClearSprites
	ld a, $1
	ld [wcfcb], a
	call Func_3e08
	call LoadScreenTilesFromBuffer2
	call LoadTextBoxTilePatterns
	call GoPAL_SET_CF1C
	jr Delay3


GBPalWhiteOutWithDelay3::
	call GBPalWhiteOut

Delay3::
; The bg map is updated each frame in thirds.
; Wait three frames to let the bg map fully update.
	ld c, 3
	jp DelayFrames

GBPalNormal::
; Reset BGP and OBP0.
	ld a, %11100100 ; 3210
	ld [rBGP], a
	ld a, %11010000 ; 3100
	ld [rOBP0], a
	ret

GBPalWhiteOut::
; White out all palettes.
	xor a
	ld [rBGP],a
	ld [rOBP0],a
	ld [rOBP1],a
	ret


GoPAL_SET_CF1C:: ; 3ded (0:3ded)
	ld b,$ff
GoPAL_SET:: ; 3def (0:3def)
	ld a,[wcf1b]
	and a
	ret z
	predef_jump Func_71ddf

GetHealthBarColor::
; Return at hl the palette of
; an HP bar e pixels long.
	ld a, e
	cp 27
	ld d, 0 ; green
	jr nc, .gotColor
	cp 10
	inc d ; yellow
	jr nc, .gotColor
	inc d ; red
.gotColor
	ld [hl], d
	ret

Func_3e08:: ; 3e08 (0:3e08)
	ld hl, wcfc4
	ld a, [hl]
	push af
	res 0, [hl]
	push hl
	xor a
	ld [W_SPRITESETID], a ; W_SPRITESETID
	call DisableLCD
	callba InitMapSprites
	call EnableLCD
	pop hl
	pop af
	ld [hl], a
	call LoadPlayerSpriteGraphics
	call LoadFontTilePatterns
	jp UpdateSprites


GiveItem::
; Give player quantity c of item b,
; and copy the item's name to wcf4b.
; Return carry on success.
	ld a, b
	ld [wd11e], a
	ld [wcf91], a
	ld a, c
	ld [wcf96], a
	ld hl,wNumBagItems
	call AddItemToInventory
	ret nc
	call GetItemName
	call CopyStringToCF4B
	scf
	ret

GivePokemon::
; Give the player monster b at level c.
	ld a, b
	ld [wcf91], a
	ld a, c
	ld [W_CURENEMYLVL], a
	xor a
	ld [wcc49], a
	ld b, BANK(_GivePokemon)
	ld hl, _GivePokemon
	jp Bankswitch


Random::
; Return a random number in a.
; For battles, use BattleRandom.
	push hl
	push de
	push bc
	callba Random_
	ld a,[hRandomAdd]
	pop bc
	pop de
	pop hl
	ret


INCLUDE "home/predef.asm"


Func_3ead:: ; 3ead (0:3ead)
	ld b, BANK(CinnabarGymQuiz_1eb0a)
	ld hl, CinnabarGymQuiz_1eb0a
	jp Bankswitch

Func_3eb5:: ; 3eb5 (0:3eb5)
	ld a, [H_LOADEDROMBANK]
	push af
	ld a, [hJoyHeld]
	bit 0, a
	jr z, .asm_3eea
	ld a, Bank(Func_469a0)
	ld [$2000], a
	ld [H_LOADEDROMBANK], a
	call Func_469a0
	ld a, [$ffee]
	and a
	jr nz, .asm_3edd
	ld a, [wTrainerEngageDistance]
	ld [$2000], a
	ld [H_LOADEDROMBANK], a
	ld de, .asm_3eda
	push de
	jp [hl]
.asm_3eda
	xor a
	jr .asm_3eec
.asm_3edd
	callba PrintBookshelfText
	ld a, [$ffdb]
	and a
	jr z, .asm_3eec
.asm_3eea
	ld a, $ff
.asm_3eec
	ld [$ffeb], a
	pop af
	ld [$2000], a
	ld [H_LOADEDROMBANK], a
	ret

PrintPredefTextID:: ; 3ef5 (0:3ef5)
	ld [H_DOWNARROWBLINKCNT2], a ; $ff8c
	ld hl, PointerTable_3f22
	call Func_3f0f
	ld hl, wcf11
	set 0, [hl]
	call DisplayTextID

Func_3f05:: ; 3f05 (0:3f05)
	ld hl, W_MAPTEXTPTR ; wd36c
	ld a, [$ffec]
	ld [hli], a
	ld a, [$ffed]
	ld [hl], a
	ret

Func_3f0f:: ; 3f0f (0:3f0f)
	ld a, [W_MAPTEXTPTR] ; wd36c
	ld [$ffec], a
	ld a, [W_MAPTEXTPTR + 1]
	ld [$ffed], a
	ld a, l
	ld [W_MAPTEXTPTR], a ; wd36c
	ld a, h
	ld [W_MAPTEXTPTR + 1], a
	ret

PointerTable_3f22:: ; 3f22 (0:3f22)
	dw CardKeySuccessText                   ; id = 01
	dw CardKeyFailText                      ; id = 02
	dw RedBedroomPC                         ; id = 03
	dw RedBedroomSNESText                   ; id = 04
	dw PushStartText                        ; id = 05
	dw SaveOptionText                       ; id = 06
	dw StrengthsAndWeaknessesText           ; id = 07
	dw OakLabEmailText                      ; id = 08
	dw AerodactylFossilText                 ; id = 09
	dw Route15UpstairsBinocularsText        ; id = 0A
	dw KabutopsFossilText                   ; id = 0B
	dw GymStatueText1                       ; id = 0C
	dw GymStatueText2                       ; id = 0D
	dw BookcaseText                         ; id = 0E
	dw ViridianCityPokecenterBenchGuyText   ; id = 0F
	dw PewterCityPokecenterBenchGuyText     ; id = 10
	dw CeruleanCityPokecenterBenchGuyText   ; id = 11
	dw LavenderCityPokecenterBenchGuyText   ; id = 12
	dw VermilionCityPokecenterBenchGuyText  ; id = 13
	dw CeladonCityPokecenterBenchGuyText    ; id = 14
	dw CeladonCityHotelText                 ; id = 15
	dw FuchsiaCityPokecenterBenchGuyText    ; id = 16
	dw CinnabarIslandPokecenterBenchGuyText ; id = 17
	dw SaffronCityPokecenterBenchGuyText    ; id = 18
	dw MtMoonPokecenterBenchGuyText         ; id = 19
	dw RockTunnelPokecenterBenchGuyText     ; id = 1A
	dw UnusedBenchGuyText1                  ; id = 1B
	dw UnusedBenchGuyText2                  ; id = 1C
	dw UnusedBenchGuyText3                  ; id = 1D
	dw TerminatorText_62508                 ; id = 1E
	dw PredefText1f                         ; id = 1F
	dw ViridianSchoolNotebook               ; id = 20
	dw ViridianSchoolBlackboard             ; id = 21
	dw JustAMomentText                      ; id = 22
	dw PredefText23                         ; id = 23
	dw FoundHiddenItemText                  ; id = 24
	dw HiddenItemBagFullText                ; id = 25
	dw VermilionGymTrashText                ; id = 26
	dw IndigoPlateauHQText                  ; id = 27
	dw GameCornerOutOfOrderText             ; id = 28
	dw GameCornerOutToLunchText             ; id = 29
	dw GameCornerSomeonesKeysText           ; id = 2A
	dw FoundHiddenCoinsText                 ; id = 2B
	dw DroppedHiddenCoinsText               ; id = 2C
	dw BillsHouseMonitorText                ; id = 2D
	dw BillsHouseInitiatedText              ; id = 2E
	dw BillsHousePokemonList                ; id = 2F
	dw MagazinesText                        ; id = 30
	dw CinnabarGymQuiz                      ; id = 31
	dw GameCornerNoCoinsText                ; id = 32
	dw GameCornerCoinCaseText               ; id = 33
	dw LinkCableHelp                        ; id = 34
	dw TMNotebook                           ; id = 35
	dw FightingDojoText                     ; id = 36
	dw FightingDojoText_52a10               ; id = 37
	dw FightingDojoText_52a1d               ; id = 38
	dw NewBicycleText                       ; id = 39
	dw IndigoPlateauStatues                 ; id = 3A
	dw VermilionGymTrashSuccesText1         ; id = 3B
	dw VermilionGymTrashSuccesText2         ; id = 3C
	dw VermilionGymTrashSuccesText3         ; id = 3D
	dw VermilionGymTrashFailText            ; id = 3E
	dw TownMapText                          ; id = 3F
	dw BookOrSculptureText                  ; id = 40
	dw ElevatorText                         ; id = 41
	dw PokemonStuffText                     ; id = 42
