extends Node


@export var map_generator: MapGenerator
var thread: Thread


func _ready() -> void:
	map_generator.init()

	thread = Thread.new()
	thread.start(_run_all)


func _process(_delta: float) -> void:
	if thread.is_alive():
		return

	thread.wait_to_finish()
	get_tree().quit()


func _run_all() -> void:
	_run(10)
	_run(25)
	_run(50)
	_run(75)


func _run(region_size: int, generations: int = 1000) -> void:
	var average_attempts := 0.0
	var average_time_elapsed := 0.0

	for i in generations:
		var start_time := Time.get_ticks_usec()
		while not await map_generator.generate(region_size):
			average_attempts += 1.0
		average_attempts += 1.0
		average_time_elapsed += Time.get_ticks_usec() - start_time

	average_attempts /= generations
	average_time_elapsed /= generations

	print("-----------------------------------")
	print("== Region size : %s == Generations : %s ==" % [region_size, generations])
	print("Average attempts per generation: %s" % [average_attempts])
	print("Average time per generation: %s" % [average_time_elapsed])

func _run_single_attempt(region_size: int, attempts: int = 1000) -> void:
	var successes := 0
	var total_time_elapsed := 0
	for i in attempts:
		var start_time := Time.get_ticks_usec()
		var success := await map_generator.generate(region_size)
		var time_elapsed := Time.get_ticks_usec() - start_time

		if success:
			successes += 1
			total_time_elapsed += time_elapsed


	var avg_time_success := float(total_time_elapsed) / float(successes)
	print("--------------------------------")
	print("Successful/total attempts: %s/%s" % [successes, attempts])
	print("Success rate: %s%%" % [float(successes) / float(attempts) * 100.0])
	print("Average time for successful attempts: %sµs" % [avg_time_success])
	print("Total time elapsed: %sµs" % [total_time_elapsed])
