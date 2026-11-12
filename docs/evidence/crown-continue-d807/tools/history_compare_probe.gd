extends SceneTree
func _initialize()->void:
 var original:Array=[{"seconds":181.966666666704,"health":60.0,"sector":24,"blind":false}]
 var decoded=JSON.parse_string(JSON.stringify(original))
 var tests:Array=[equivalent_history(original,decoded),equivalent_history(12.5,12.5+0.0000000001),not equivalent_history(12.5,12.5+0.000001),not equivalent_history(24,24.0000000001),not equivalent_history(false,0),not equivalent_history([1,2],[2,1]),not equivalent_history({"a":1},{"a":1,"b":2}),not equivalent_history({"a":1},{}),not equivalent_history(60.0,59.99),not equivalent_history("24",24)]
 print("HISTORY_COMPARE_PROBE ",JSON.stringify({"passed":tests.all(func(x):return x),"checks":tests,"old_exact_equality":original==decoded}))
 quit(0 if tests.all(func(x):return x) else 1)

static func equivalent_history(a:Variant,b:Variant)->bool:
 var ta:=typeof(a);var tb:=typeof(b)
 if ta in [TYPE_INT,TYPE_FLOAT] and tb in [TYPE_INT,TYPE_FLOAT]:
  if not is_finite(float(a)) or not is_finite(float(b)):return false
  if ta==TYPE_INT or tb==TYPE_INT:return a==b
  return absf(float(a)-float(b))<=0.000000001
 if ta!=tb:return false
 if ta==TYPE_ARRAY:
  if a.size()!=b.size():return false
  for i in a.size():
   if not equivalent_history(a[i],b[i]):return false
  return true
 if ta==TYPE_DICTIONARY:
  if a.size()!=b.size():return false
  for k in a:
   if not b.has(k) or not equivalent_history(a[k],b[k]):return false
  return true
 return a==b
