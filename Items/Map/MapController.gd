extends TileMap

var HasUpdatedCellData: bool = false

#Can't use setget on arrays, or maybe arrays but not typed arrays. Append is not considered a 'set' command so only at index commands will be copied anyway. Might be able to work arround this but don't want to rely on artifatcs of the current mutlipayer varaible syncroniation system for something as critical as map syncing.

#No longer using arrays, read/write requires an indexing system which negates the performance benefit of using array index overlap as link. Reading Positions and IDs separately may be faster if staggered separately but can be added later and merged into local dictionaries.

#Last change from server, considered highest authority on accuracy
var SyncedData: Dictionary = {}
#Current map state, presumably faster than reading tilemap again
var CurrentData: Dictionary = {}
#Local modifications buffered untill next sync cycle
var ChangedData: Dictionary= {}
var ChangedDataFailedCycles: Dictionary = {}

#NOTE : Godot passes all dictionaries by reference, remember that.

func _ready() -> void:
	if(multiplayer.is_server()):
		print(GetCellIDs)
	'''
	var Positions: Array[Vector2i] = get_used_cells(0)

	for Val in Positions:
		print(Val)	

	return
	'''



	if(multiplayer.is_server()):
		#Not sure if this is allowd
		SyncedData[GetCellPositions(0)] = GetCellIDs(0)
		HasUpdatedCellData = true
	else:
		RequestBlockState.rpc()

var CurrentCycleTime: float = 0.0
func _process(delta: float) -> void:
	#Helpers.log_print("af8ah0         1")
	CurrentCycleTime+=delta
	if(CurrentCycleTime>0.2):
		#Helpers.log_print("af8ah0         2")
		PushChangedData()
		CurrentCycleTime = 0.0

	if(Globals.local_debug_instance_number == 2 and DebugCount > 0):
		DebugCount-=1
		if(DebugCount < 300):
			ModifyCell(Vector2i(-5,-5), Vector2i(1,1))
			ModifyCell(Vector2i(-4,-5), Vector2i(1,1))
			ModifyCell(Vector2i(-3,-5), Vector2i(1,1))
			ModifyCell(Vector2i(-2,-5), Vector2i(1,1))
			if(DebugCount == 200):
					Helpers.log_print("C")
					ModifyCell(Vector2i(-5,-10), Vector2i(1,1))
					ModifyCell(Vector2i(-4,-10), Vector2i(1,1))
					ModifyCell(Vector2i(-3,-10), Vector2i(1,1))
					ModifyCell(Vector2i(-2,-10), Vector2i(1,1))
			#ModifyCell(Vector2i(randi_range(-50,50),randi_range(-50,50)), Vector2i(1,1))

var DebugCount = 400

func SetAllCellData(Data: Dictionary, Layer: int) -> void:
	clear_layer(Layer)
	for Key: Vector2i in Data.keys:
		set_cell(Layer, Key,Data[Key])

func GetCellPositions(Layer: int) -> Array[Vector2i]:
	var Positions: Array[Vector2i] = get_used_cells(Layer)
	return(Positions)

func GetCellIDs(Layer):
	var IDs: Array[Vector2i]
	var Positions: Array[Vector2i] = get_used_cells(Layer)

	for Position in Positions:
		IDs.append(get_cell_atlas_coords(Layer,Position))
	return(IDs)

@rpc("any_peer", "call_remote", "reliable")
func RequestBlockState() -> void:
	if(multiplayer.is_server()):
		#Targeted RPC's don't appear to exist
		#var sender_id = multiplayer.get_remote_sender_id()
		SendBlockState.rpc(SyncedData)

@rpc("authority", "call_remote", "reliable")
func SendBlockState(Data: Dictionary) -> void:
	if(!HasUpdatedCellData):
		HasUpdatedCellData = true
		SyncedData = Data
		CurrentData = Data
		SetAllCellData(Data,0)

#Architecture plan:

	#Players modify local data
	#Push data to server, store buffered status
	#Server recieves push and overwrites local data
	#Server pushes modifications to all clients
	#Recieving client checks if modification block matches sent changes, if so, remove changes from marked chages store
	#If recieved block do not match changes, maintain changes and re-send up to capped reattempt count (per index)
	#If re-attempt count exceeds cap discard changes and restore synced copy
	#Failed local state revision drops placed cells, drop items are not spawned untill state change is confirmed

	#Design Issues:
		#Empty cells considered empty data, requires updating entire tile map for empty refresh (expensive?)
		#Solution is to store remove tile chages as separate system

func ModifyCell(Position: Vector2i, ID: Vector2i) -> void:
	if(!HasUpdatedCellData):
		#Not allowd to modify map untill first state recieved
		#Because current map is not trustworthy, not cleared on start so player doesn't fall through world immediately.
		return
	ChangedData[Position] = ID
	ChangedDataFailedCycles[Position] = 0
	SetCellData(Position,ID)


func SetCellData(Position: Vector2i, ID: Vector2i) -> void:
	CurrentData[Position] = ID
	set_cell(0,Position,0,ID)

func PushChangedData() -> void:
	if(len(ChangedData.keys()) > 0): # ### DAD SAYS! ### <- These are NEVER both true, so I set it to or just to hack it into existence
		RPCSendChangedData.rpc(ChangedData)
		ChangedData.clear()

@rpc("any_peer", "call_remote", "reliable")
func RPCSendChangedData(Data: Dictionary) -> void:
	if(multiplayer.is_server()):
		var AcceptedChanges: Dictionary = Dictionary()
		var ChangeMade: bool = false
		for Key: Vector2i in Data.keys():
			if(Data[Key] != Vector2i(-1,-1) and (!SyncedData.has(Key) or SyncedData[Key] == Vector2i(-1,-1))):
				#Replace air with Cell, valid
				AcceptedChanges[Key] = Data[Key]
				SyncedData[Key] = Data[Key]
				ChangeMade = true
			elif (Data[Key] == Vector2i(-1,-1)):
				#Replace with air, valid
				AcceptedChanges[Key] = Data[Key]
				SyncedData[Key] = Data[Key]
				ChangeMade = true
		#SyncedData[AcceptedChanges.keys()] = AcceptedChanges.values()
		if(ChangeMade):
			ServerSendChangedData.rpc(AcceptedChanges)

const MaxFailedChangeCycles = 2

@rpc("authority", "call_remote", "reliable")
func ServerSendChangedData(Data: Dictionary) -> void:
	if(multiplayer.is_server()):
		return
	for Key: Vector2i in Data.keys():
		SyncedData[Key] = Data[Key]
		CurrentData[Key] = Data[Key]
		UpdateCellFromCurrent(Key)

func UpdateCellFromCurrent(Position):
	set_cell(0,Position,0,CurrentData[Position])