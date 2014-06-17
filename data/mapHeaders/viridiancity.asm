ViridianCity_h: ; 0x18357 to 0x18384 (45 bytes) (bank=6) (id=1)
	db OVERWORLD ; tileset
	db VIRIDIAN_CITY_HEIGHT, VIRIDIAN_CITY_WIDTH ; dimensions (y, x)
	dw ViridianCityBlocks, ViridianCityTextPointers, ViridianCityScript ; blocks, texts, scripts
	db NORTH | SOUTH | WEST ; connections
	NORTH_MAP_CONNECTION ROUTE_2, ROUTE_2_WIDTH, ROUTE_2_HEIGHT, 16, 0, ROUTE_2_WIDTH, Route2Blocks
	SOUTH_MAP_CONNECTION ROUTE_1, ROUTE_1_WIDTH, 5, 0, ROUTE_1_WIDTH, Route1Blocks, VIRIDIAN_CITY_WIDTH, VIRIDIAN_CITY_HEIGHT
	WEST_MAP_CONNECTION ROUTE_1, ROUTE_1_WIDTH, 5, 0, ROUTE_1_WIDTH, Route1Blocks, VIRIDIAN_CITY_WIDTH, VIRIDIAN_CITY_HEIGHT
	dw ViridianCityObject ; objects
