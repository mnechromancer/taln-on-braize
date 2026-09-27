class_name StationContext
extends Node
## Which station of the cycle this is (spec §1.1, §2.2, §8.2). The station
## value v multiplies all Investiture income; the spawner reads the same index
## for its S, D and P multipliers.

signal station_changed(index: int)

@export var tuning: InvestitureTuning

var station_index: int = 0:
	set(value):
		if value == station_index:
			return
		station_index = value
		station_changed.emit(value)


## v = 1 / 2 / 3 by station (spec §2.2).
func value() -> float:
	return tuning.station_values[clampi(station_index, 0, tuning.station_values.size() - 1)]
