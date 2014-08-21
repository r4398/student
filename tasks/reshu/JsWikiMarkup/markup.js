(function(jQuery) {
    if (typeof(jQuery.reshu) === "undefined") {
        jQuery.reshu = {}
    }

    var plugin

    // function Test() {
    // 	if(this == window) return new Test()
    // 	else {
    // 	    this.f1 = 0
    // 	}
    // }

    function Context() {
	return {
	    lists: [],
	    paragraph: function(text) {
		this.lists = []
		$(document.body).append($('<p/>').text(text))
	    },
	    header: function(level, text) {
		this.lists = []
		$(document.body).append($('<h'+level+'/>').text(text))
	    },
	    list: function(list, text) {
		var i
		for(i = 0; i < this.lists.length; ++i)
		    if(this.lists[i][0] != list[i]) {
			this.lists.length = i
			break
		    }
		var j
		for(j = i; j < list.length; ++j) {
		    var list_node = $( list[j] == '*' ? '<ul/>' : '<ol/>');
		    if(j) this.lists[j-1][2].append(list_node)
		    else $(document.body).append(list_node)
		    this.lists[j] = [list[j], list_node]
		}
		var li = this.lists[this.lists.length-1][2] = $('<li/>').text(text)
		this.lists[this.lists.length-1][1].append(li)
	    },
	    // log: function() {
	    // 	console.log(this)
	    // },
	}
    }

    plugin = jQuery.reshu.markup = function(src_base_path) {
	var url = src_base_path + location.search.replace(/^\?s=/, '')
	$.ajax({type: 'GET', url: url, success: function(text) {
	    $(document.body).append($('<pre/>').text(text))
	    var ctx = Context()
	    var pos
	    while((pos = text.indexOf('\n')) != -1) {
		var line = text.substring(0, pos)
		text = text.substring(pos + 1)
		if(line[0] == '!') {
		    var level = 0
		    while(line[++level] == '!') ;
		    if(line[level] == ' ') {
			var start = level
			while(line[++start] == ' ') ;
			if(start < line.length) {
			    ctx.header(level, line.substr(start))
			    continue
			}
		    }
		}
		else if(line[0] == '*' || line[0] == '-') {
		    var level = 0
		    while(line[++level] == '*' || line[level] == '-') ;
		    if(line[level] == ' ') {
			var start = level
			while(line[++start] == ' ') ;
			if(start < line.length) {
			    ctx.list(line.substr(0, level), line.substr(start))
			    continue
			}
		    }
		}
		ctx.paragraph(line)
	    }
	}})
    }

})(jQuery)
