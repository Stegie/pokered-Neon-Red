PickupItem:
	call EnableAutoTextBoxDrawing

	ld a, [H_DOWNARROWBLINKCNT2] ; $ff8c
	ld b, a
	ld hl, W_MISSABLEOBJECTLIST
.missableObjectsListLoop
	ld a, [hli]
	cp $ff
	ret z
	cp b
	jr z, .isMissable
	inc hl
	jr .missableObjectsListLoop

.isMissable
	ld a, [hl]
	ld [$ffdb], a

	ld hl, W_MAPSPRITEEXTRADATA
	ld a, [H_DOWNARROWBLINKCNT2] ; $ff8c
	dec a
	add a
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hl]
	ld b, a ; item
	ld c, 1 ; quantity
	call GiveItem
	jr nc, .BagFull

	ld a, [$ffdb]
	ld [wcc4d], a
	predef HideObject
	ld a, 1
	ld [wcc3c], a
	ld hl, FoundItemText
	jr .print

.BagFull
	ld hl, NoMoreRoomForItemText
.print
	call PrintText
	ret

FoundItemText:
	TX_FAR _FoundItemText
	db $0B
	db "@"

NoMoreRoomForItemText:
	TX_FAR _NoMoreRoomForItemText
	db "@"
