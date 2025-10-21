extends Node


@export var map_generator: MapGenerator


func _ready() -> void:
	map_generator.init()

	_run(10)
	_run(25)
	_run(50)
	_run(75)

	get_tree().quit()


func _run(region_size: int, attempts: int = 1000) -> void:
	var successes := 0
	var total_time_elapsed := 0
	#var out_file := FileAccess.open("user://benchmark_%s.csv" % [region_size], FileAccess.WRITE)
	for i in attempts:
		var start_time := Time.get_ticks_usec()
		var success := await map_generator.generate(region_size)
		var time_elapsed := Time.get_ticks_usec() - start_time
		#print("Time elapsed: %sµs" % [time_elapsed])

		if success:
			successes += 1
			total_time_elapsed += time_elapsed

		#var row := PackedStringArray()
		#row.append(str(success))
		#row.append(str(time_elapsed))
		#out_file.store_csv_line(row)


	var avg_time_success := float(total_time_elapsed) / float(successes)
	print("--------------------------------")
	print("Successful/total attempts: %s/%s" % [successes, attempts])
	print("Success rate: %s%%" % [float(successes) / float(attempts) * 100.0])
	print("Average time for successful attempts: %sµs" % [avg_time_success])
	print("Total time elapsed: %sµs" % [total_time_elapsed])
