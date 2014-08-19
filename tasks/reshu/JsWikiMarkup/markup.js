(function(jQuery) {
    if (typeof(jQuery.reshu) === "undefined") {
        jQuery.reshu = {}
    }

    var plugin

    plugin = jQuery.reshu.markup = function(src_base_path) {
	var url = src_base_path + location.search.replace(/^\?s=/, '')
	$.ajax({type: 'GET', url: url, success: function(text) {
	    $(document.body).append($('<pre/>').text(text))
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
			    $(document.body).append($('<h'+level+'/>').text(line.substr(start)))
			    continue
			}
		    }
		}
		$(document.body).append($('<p/>').text(line))
	    }
	}})
    }

})(jQuery)
