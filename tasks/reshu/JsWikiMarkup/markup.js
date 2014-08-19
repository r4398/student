(function(jQuery) {
    if (typeof(jQuery.reshu) === "undefined") {
        jQuery.reshu = {}
    }

    var plugin

    plugin = jQuery.reshu.markup = function(src_base_path) {
	var url = src_base_path + location.search.replace(/^\?s=/, '')
	$.ajax({type: 'GET', url: url, success: function(text) {
	    $(document.body).append($('<pre/>').text(text))
	}})
    }

})(jQuery)
