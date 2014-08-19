(function(jQuery) {
    if (typeof(jQuery.reshu) === "undefined") {
        jQuery.reshu = {}
    }

    var plugin

    plugin = jQuery.reshu.markup = function(src_base_path) {
	console.log('форель')
	console.log(src_base_path)
	var url = src_base_path + location.search.replace(/^\?s=/, '')
	console.log(url)
	$.ajax({type: 'GET', url: url, success: function(text) {
	    console.log(text)
	    $(document.body).append($('<pre/>').text(text))
	}})
    }

})(jQuery)
