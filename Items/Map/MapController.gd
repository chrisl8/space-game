extends TileMap

@export var SyncedTilePositions: Array[Vector2i]
@export var SyncedTileIDs: Array[Vector2i]

# Called when the node enters the scene tree for the first time.
func _ready():
	print("AAA")
	print(GetCellData())
	print("BBB")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func SetTileData(Positions, IDs):
	var Count = len(IDs)-1
	while(Count>=0):
		set_cell(Positions[Count],IDs[Count])
		Count-=1

func GetCellData():
	var Positions: Array[Vector2i]
	var IDs: Array[Vector2i]
	Positions = get_used_cells(0)

	for Position in Positions:
		IDs.append(get_cell_tile_data(0,Position))

	return [Positions,IDs]

func GetCellPositions():
	return(get_used_cells(0))

func GetCellIDs():
	var IDs: Array[Vector2i]

	for Position in get_used_cells(0):
		IDs.append(get_cell_tile_data(0,Position))
	return(IDs)