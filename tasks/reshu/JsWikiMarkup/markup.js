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
	    lists: 0,
	    paragraph: function(text) {
		$(document.body).append($('<p/>').text(text))
	    },
	    header: function(level, text) {
		$(document.body).append($('<h'+level+'/>').text(text))
	    },
	    list: function(list, text) {
		++this.lists
		$(document.body).append($('<ul/>').append($('<li/>').text(text)))
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
