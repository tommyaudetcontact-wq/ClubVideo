extends Control
const MONTHS:=["JANVIER","FÉVRIER","MARS","AVRIL","MAI","JUIN","JUILLET","AOÛT","SEPTEMBRE","OCTOBRE","NOVEMBRE","DÉCEMBRE"]
var movies:Array=[]
var previews:Array=[]
var date:Dictionary={}
var cells:Array=[]
var first_column:=0
var events:Dictionary={}
var next_release:Dictionary={}
var next_bundle:Dictionary={}

func configure(rules) -> void:
	date=rules.calendar()
	previews=[]
	events={}
	for id in rules.upcoming:
		var release_day:int=int(rules.release_days.get(int(id),rules.next_release))
		var release_date:=Time.get_date_dict_from_unix_time(rules.START_DATE+(release_day-1)*86400)
		if release_date.month==date.month and release_date.year==date.year and int(id)<movies.size():events[int(release_date.day)]=movies[int(id)]
	for id in rules.upcoming.slice(0,3):
		if int(id)>=movies.size():continue
		var movie:Dictionary=movies[int(id)]
		previews.append({"title":str(movie.title),"cover":load(str(movie.frontCover).replace("./","res://"))})
	var first:=Time.get_date_dict_from_unix_time(Time.get_unix_time_from_datetime_dict({"year":date.year,"month":date.month,"day":1}))
	first_column=(int(first.weekday)+6)%7
	next_release=Time.get_date_dict_from_unix_time(rules.START_DATE+(rules.next_release-1)*86400)
	next_bundle=Time.get_date_dict_from_unix_time(rules.START_DATE+(rules.next_bundle-1)*86400)
	cells=[]
	for day in range(1,rules.calendar_days()+1):
		var index:=first_column+day-1
		cells.append({"day":day,"column":index%7,"row":int(index/7),"crossed":day<int(date.day),"circled":day==int(date.day),"release":next_release.year==date.year and next_release.month==date.month and next_release.day==day,"bundle":next_bundle.year==date.year and next_bundle.month==date.month and next_bundle.day==day})
	queue_redraw()
	var viewport:=get_viewport() as SubViewport
	if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func _draw() -> void:
	if date.is_empty():return
	var font:=ThemeDB.fallback_font
	draw_rect(Rect2(0,0,768,672),Color("f1ecdb"))
	draw_rect(Rect2(0,0,768,90),Color("223e65"))
	draw_string(font,Vector2(30,59),"%s %d"%[MONTHS[int(date.month)-1],int(date.year)],HORIZONTAL_ALIGNMENT_LEFT,-1,43,Color("f5eacb"))
	var columns:=["LU","MA","ME","JE","VE","SA","DI"]
	for column in 7:
		draw_string(font,Vector2(38+column*100,125),columns[column],HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("526274"))
	for row in range(7):draw_line(Vector2(30,142+row*55),Vector2(730,142+row*55),Color("bdc0b5"),1,true)
	for column in range(8):draw_line(Vector2(30+column*100,142),Vector2(30+column*100,472),Color("bdc0b5"),1,true)
	for cell in cells:
		var center:=Vector2(80+int(cell.column)*100,168+int(cell.row)*55)
		draw_string(font,center+Vector2(-16,10),str(cell.day),HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("2d3942"))
		if cell.crossed:
			draw_line(center+Vector2(-29,-24),center+Vector2(30,23),Color("8c3c37"),3,true)
			draw_line(center+Vector2(28,-24),center+Vector2(-30,24),Color("8c3c37"),3,true)
		elif cell.circled:draw_arc(center,29,.1,TAU+.1,64,Color("a33c35"),3,true)
		if events.has(int(cell.day)):
			var title:String=str(events[int(cell.day)].title)
			draw_rect(Rect2(center+Vector2(-47,-24),Vector2(94,49)),Color(.86,.91,.96,.7))
			draw_string(font,center+Vector2(-40,-4),str(cell.day),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("1b4169"))
			draw_string(font,center+Vector2(-41,13),title.left(12),HORIZONTAL_ALIGNMENT_LEFT,90,13,Color("174975"))
			draw_string(font,center+Vector2(-41,25),title.substr(12,12),HORIZONTAL_ALIGNMENT_LEFT,90,13,Color("174975"))
		if cell.release:draw_string(font,center+Vector2(23,-13),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("265a89"))
		if cell.bundle:draw_string(font,center+Vector2(23,20),"L",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("547345"))
	draw_rect(Rect2(0,482,768,190),Color("e3dec9"))
	for index in previews.size():
		var x:float=24+index*250
		draw_texture_rect(previews[index].cover,Rect2(x,511,80,115),false)
		draw_string(font,Vector2(x+90,530),"%02d/%02d"%[next_release.day,next_release.month] if index==0 else "À SUIVRE",HORIZONTAL_ALIGNMENT_LEFT,145,23,Color("254e77"))
		var words:PackedStringArray=str(previews[index].title).split(" ")
		var line:="";var y:=559.0
		for word in words:
			if line.length()+word.length()>14:
				draw_string(font,Vector2(x+90,y),line,HORIZONTAL_ALIGNMENT_LEFT,145,19,Color("344453"));y+=23;line=""
			line+=word+" "
		if y<627:draw_string(font,Vector2(x+90,y),line,HORIZONTAL_ALIGNMENT_LEFT,145,19,Color("344453"))
	draw_string(font,Vector2(25,501),"LES PROCHAINES SORTIES AU CLUB",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("526274"))
	draw_string(font,Vector2(25,655),"N : nouvelle sortie     L : arrivage de lots",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("475767"))
