extends SceneTree
func _initialize()->void:
 var value:Array=[{"seconds":181.966666666704,"health":60.0,"sector":24}]
 var encoded:=JSON.stringify(value)
 var decoded=JSON.parse_string(encoded)
 print(JSON.stringify({"encoded":encoded,"arrays_equal":value==decoded,"live_time":value[0].seconds,"saved_time":decoded[0].seconds,"difference":absf(value[0].seconds-decoded[0].seconds),"individual_equal":value[0].seconds==decoded[0].seconds}))
 quit()
