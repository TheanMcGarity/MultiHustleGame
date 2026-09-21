extends Resource

class_name MHDialogueInstance

export var next := ""

export var text := "default text"
export var color := Color.white
export(int, 0, 300) var length_ticks = 100

export var state_name = "Wait"
export var state_extra = { }
export var state_data = { }

export(Array, Resource) var triggers = []
