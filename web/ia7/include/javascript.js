var collection_json;  //global storage for collection database
var entity_store = {}; //global storage of entities
var updateSocket;

//Takes the current location and parses the achor element into a hash
function URLToHash() {
	if (location.hash === undefined) return;
	var URLHash = {};
	var url = location.hash.replace(/^\#/, ''); //Replace Hash Entity
	var pairs = url.split('&');
	for (var i = 0; i < pairs.length; i++) {
		var pair = pairs[i].split('=');
		URLHash[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
	}
	return URLHash;
}

//Takes a hash and turns it back into a url
function HashtoURL(URLHash) {
	var pairs = [];
	for (var key in URLHash){
		if (URLHash.hasOwnProperty(key)){
			pairs.push(encodeURIComponent(key) + '=' + encodeURIComponent(URLHash[key]));
		}
	}
	return location.path + "#" + pairs.join('&');
}

//Called anytime the page changes
function changePage (){
	if (collection_json === undefined){
		$.ajax({
			type: "GET",
			url: '/ia7/include/collections.pl',
			dataType: "json",
			success: function( json ) {
				collection_json = json;
				changePage();
			}
		});
	} 
	else { //We have the database
		var URLHash = URLToHash();
		if (URLHash.request == 'list'){
			loadList(URLHash.type,URLHash.name, URLHash.collection_key);
		}
		else if(URLHash.request == 'page'){
			$.get(URLHash.link, function( data ) {
				data = data.replace(/<link[^>]*>/img, ''); //Remove stylesheets
				data = data.replace(/<title[^>]*>((\r|\n|.)*?)<\/title[^>]*>/img, ''); //Remove title
				data = data.replace(/<meta[^>]*>/img, ''); //Remove meta refresh
				data = data.replace(/<base[^>]*>/img, ''); //Remove base target tags
				$('#list_content').html("<div id='buffer_page' class='row top-buffer'>");
				$('#buffer_page').append("<div id='row_page' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
				$('#row_page').html(data);
			});
		}
		else if(URLHash.request == 'print_log'){
			print_log();
		}
		else if(URLHash.request == 'trigger'){
			trigger();
		}
		else { //default response is to load a collection
			loadCollection(URLHash.collection_key);
		}
		//update the breadcrumb
		$('#nav').html('');
		var collection_keys_arr = URLHash.collection_key;
		if (collection_keys_arr === undefined) collection_keys_arr = '0';
		collection_keys_arr = collection_keys_arr.split(',');
		var breadcrumb = '';
		for (var i = 0; i < collection_keys_arr.length; i++){
			var nav_link, nav_name;
			if (collection_keys_arr[i].substring(0,1) == "$"){
				//We are browsing the contents of an object, currently only 
				//group objects can be browsed recursively.  Possibly use different
				//prefix if other recursively browsable formats are later added
				nav_name = collection_keys_arr[i].replace("$", '');
				nav_link = '#request=list&type=groups&name='+nav_name; //ATM There is only a single level of these
			}
			else {
				nav_link = collection_json.collections[collection_keys_arr[i]].link;
				nav_name = collection_json.collections[collection_keys_arr[i]].name;
			}
			nav_link = buildLink (nav_link, breadcrumb + collection_keys_arr[i]);
			breadcrumb += collection_keys_arr[i] + ",";
			if (i == (collection_keys_arr.length-1)){
				$('#nav').append('<li class="active">' + nav_name + '</a></li>');
				$('title').html("MisterHouse - " + nav_name);
			} 
			else {
				$('#nav').append('<li><a href="' + nav_link + '">' + nav_name + '</a></li>');
			}
		}
	}
}

//Recursively parses a JSON entity to print all variables 
function variableList(value){
	var retValue = '';
	if (typeof value == 'object' && value !== null) {
		var keys = [];
		for (var key in value) {
			keys.push(key);
		}
		keys.sort ();
		for (var i = 0; i < keys.length; i++){
			retValue += "<ul><li><b>" + keys[i] +":</b>"+ variableList(value[keys[i]]) + "</li></ul>";
		}
	} else {
		retValue = "<ul><li>" + value+"</li></ul>";
	}
	return retValue;
}

//Prints a JSON generated list of MH objects
var loadList = function(listType,listValue,collection_key) {
	var url;
	if (listValue !== undefined){
		var recursive = '';
		if (listType == 'groups') {
			recursive = ',not_recursive';
		}
		url = "/sub?json("+listType+"="+listValue+",'fields=text|type|state|states|label|idle_time|sort_order"+recursive+"')";
	} 
	else {
		var recursive = ',not_recursive';
		url = "/sub?json("+listType+",'fields=text|type|state|states|label|idle_time|sort_order"+recursive+"')";
	}
	$.ajax({
	type: "GET",
	url: url,
	dataType: "json",
	success: function( json ) {
		var button_text = '';
		var button_html = '';
		var entity_arr = [];
		var list_output = "";
		for (var json_type in json){
			if (json_type == 'time' || json_type == 'request' || json_type == 'options') {
				//These are management values
				continue;
			}
			if (json_type.toLowerCase() == 'save' || json_type.toLowerCase() == 'vars' ){ //variables list
				var keys = [];
				for (var key in json[json_type]) {
					keys.push(key);
				}
				keys.sort ();
				for (var i = 0; i < keys.length; i++){
					var value = variableList(json[json_type][keys[i]]);
					var name = keys[i];
					var list_html = "<ul><li><b>" + name + ":</b>" + value+"</li></ul>";
					list_output += (list_html);
				}
				continue;
			}
			for (var division in json[json_type]){
				if (listValue === undefined){ //truncated list
					button_text = division;
					//Put entities into button
					button_html = "<div style='vertical-align:middle'><a role='button' listType='"+listType+"'";
					button_html += "class='btn btn-default btn-lg btn-block btn-list btn-division'";
					button_html += "href='#request=list&collection_key="+collection_key+",$" + button_text + "&type="+listType+"&name="+button_text+"' >";
					button_html += "" +button_text+"</a></div>";
					entity_arr.push(button_html);
					continue;
				}//end truncated list
				if (json_type == 'groups'){
					$('#toolButton').attr("entity", division);
				}
				// Build list entities
				var entity_list = [];
				for(var k in json[json_type][division]) entity_list.push(k);
				var sort_list = json[json_type][division].sort_order;
				// Sort that list if a sort exists, probably exists a shorter way to
				// write the sort
				entity_list.sort(function(a,b) {
					if (sort_list.indexOf(a) < 0) {
						return 1;
					}
					else if (sort_list.indexOf(b) < 0) {
						return -1;
					}
					else {
						return sort_list.indexOf(a) - sort_list.indexOf(b);
					}
				});
				if (entity_store[division] === undefined){
					entity_store[division] = {};
				}
				entity_store[division].sort_order = entity_list;
				for (var i = 0; i < entity_list.length; i++) {
					var entity = entity_list[i];
					if (json[json_type][division][entity].type === undefined){
						// This is not an entity, likely a value of the root obj
						continue;
					}
					if (json[json_type][division][entity].type == "Voice_Cmd"){
						button_text = json[json_type][division][entity].text;
						//Choose the first alternative of {} group
						while (button_text.indexOf('{') >= 0){
							var regex = /([^\{]*)\{([^,]*)[^\}]*\}(.*)/;
							button_text = button_text.replace(regex, "$1$2$3");
						}
						//Put each option in [] into toggle list, use first option by default
						if (button_text.indexOf('[') >= 0){
							var regex = /(.*)\[([^\]]*)\](.*)/;
							var options = button_text.replace(regex, "$2");
							var button_text_start = button_text.replace(regex, "$1");
							var button_text_end = button_text.replace(regex, "$3");
							options = options.split(',');
							button_html = '<div class="btn-group btn-block fillsplit">';
							button_html += '<div class="leadcontainer">';
							button_html += '<button type="button" class="btn btn-default dropdown-lead btn-lg btn-list btn-voice-cmd">'+button_text_start + "<u>" + options[0] + "</u>" + button_text_end+'</button>';
							button_html += '</div>';
							button_html += '<button type="button" class="btn btn-default btn-lg dropdown-toggle pull-right btn-list-dropdown" data-toggle="dropdown">';
							button_html += '<span class="caret"></span>';
							button_html += '<span class="sr-only">Toggle Dropdown</span>';
							button_html += '</button>';
							button_html += '<ul class="dropdown-menu dropdown-voice-cmd" role="menu">';
							for (var i=0,len=options.length; i<len; i++) { 
								button_html += '<li><a href="#">'+options[i]+'</a></li>';
							}
							button_html += '</ul>';
							button_html += '</div>';
						}
						else {
							button_html = "<div style='vertical-align:middle'><button type='button' class='btn btn-default btn-lg btn-block btn-list btn-voice-cmd'>";
							button_html += "" +button_text+"</button></div>";
						}
						entity_arr.push(button_html);
					} //Voice Command Button
					else if(json[json_type][division][entity].type == "Group"){
						entity_store[entity] = json[json_type][division][entity];
						var object = json[json_type][division][entity];
						button_text = entity;
						if (object.label !== undefined) button_text = object.label;
						//Put entities into button
						button_html = "<div style='vertical-align:middle'><a role='button' listType='"+json_type+"'";
						button_html += "class='btn btn-default btn-lg btn-block btn-list btn-division'";
						button_html += "href='#request=list&collection_key="+collection_key+",$" + entity + "&type="+json_type+"&name="+entity+"' >";
						button_html += "" +button_text+"</a></div>";
						entity_arr.push(button_html);
						continue;
					}
					else {
						entity_store[entity] = json[json_type][division][entity];
						var name = entity;
						if (entity_store[entity].label !== undefined) name = entity_store[entity].label;
						//Put objects into button
						button_html = "<div style='vertical-align:middle'><button entity='"+entity+"' division='"+division+"' ";
						button_html += "class='btn btn-default btn-lg btn-block btn-list btn-popover btn-state-cmd'>";
						button_html += name+"<span class='pull-right'>"+entity_store[entity].state+"</span></button></div>";
						entity_arr.push(button_html);
					} //Not voice command button
				}//entity each loop
			}//division loop
		}//json_type loop
		//clear list_content if we have something to print
		if (entity_arr.length > 0 || list_output !== ""){
			$('#list_content').html('');
		}
		//loop through array and print buttons
		var row = 0;
		var column = 1;
		for (var i = 0; i < entity_arr.length; i++){
			if (column == 1){
				$('#list_content').append("<div id='buffer"+row+"' class='row top-buffer'>");
				$('#buffer'+row).append("<div id='row" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
			}
			$('#row'+row).append("<div class='col-sm-4'>" + entity_arr[i] + "</div>");
			if (column == 3){
				column = 0;
				row++;
			}
			column++;
		}
		//Print list output if exists;
		if (list_output !== ""){
			$('#list_content').append("<div id='buffer_vars' class='row top-buffer'>");
			$('#buffer_vars').append("<div id='row_vars' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
			$('#row_vars').append(list_output);
		}
		//Affix functions to all button clicks
		$(".dropdown-voice-cmd > li > a").click( function (e) {
			var button_group = $(this).parents('.btn-group');
			button_group.find('.leadcontainer > .dropdown-lead >u').html($(this).text());
			e.preventDefault();
		});
		$(".btn-voice-cmd").click( function () {
			var voice_cmd = $(this).text().replace(/ /g, "_");
			var url = '/RUN;last_response?select_cmd=' + voice_cmd;
			$.get( url, function(data) {
				var start = data.toLowerCase().indexOf('<body>') + 6;
				var end = data.toLowerCase().indexOf('</body>');
				$('#lastResponse').find('.modal-body').html(data.substring(start, end));
				$('#lastResponse').modal({
					show: true
				});
			});
		});
		$(".btn-state-cmd").click( function () {
			var entity = $(this).attr("entity");
			var name = entity;
			if (entity_store[entity].label !== undefined) name = entity_store[entity].label;
			$('#control').modal('show');
			var modal_state = entity_store[entity].state;
			$('#control').find('.object-title').html(name + " - " + entity_store[entity].state);
			$('#control').find('.control-dialog').attr("entity", entity);
			$('#control').find('.states').html('<div class="btn-group"></div>');
			var modal_states = entity_store[entity].states;
			for (var i = 0; i < modal_states.length; i++){
				$('#control').find('.states').find('.btn-group').append("<button class='btn btn-default'>"+modal_states[i]+"</button>");
			}
			$('#control').find('.states').find(".btn-default").click(function (){
				url= '/SET;none?select_item='+$(this).parents('.control-dialog').attr("entity")+'&select_state='+$(this).text();
				$('#control').modal('hide');
				$.get( url);
			});
		});
		
		// Continuously check for updates if this was a group type request
		updateList(json['request'], json['options'], json['time']);
		}//success function
	});  //ajax request
};//loadlistfunction

//Used to dynamically update the state of a list
var updateList = function(request, options, time) {
	//There is probably a better way to rebuild the query, but this works
	options['long_poll'] = [];
	options['time'] = [time];
	var args = "'";
	var i = 0;
	for (var key in request) {
		if (i > 0) {
			args += ",";
		}
		args += key + "=" + request[key].join('|');
		i++;
	}
	args += "','";
	i = 0;
	for (var key in options) {
		if (i > 0) {
			args += ",";
		}
		args += key + "=" + options[key].join('|');
		i++;
	}
	args +="'";
	var url = "/LONG_POLL?json("+args+")";
	if (updateSocket !== undefined && updateSocket.readyState != 4){
		// Only allow one update thread to run at once
		updateSocket.abort();
	}
	updateSocket = $.ajax({
		type: "GET",
		url: url,
		dataType: "json",
		success: function( json, textStatus, jqXHR) {
			var requestTime = time;
			if (jqXHR.status == 200) {
				for (var json_type in json){
					//we likely want a specific parser for handling the JSON response
					if (json_type == 'time' || json_type == 'request' || json_type == 'options') {
						//These are management values
						continue;
					}
					for (var division in json[json_type]){
						for (var entity in json[json_type][division]){
							if (json[json_type][division][entity].type === undefined){
								// This is not an entity, likely a value of the root obj
								continue;
							}
							$('button[entity="'+entity+'"]').find('.pull-right').text(
								json[json_type][division][entity]['state']
							);
							entity_store[entity].state = json[json_type][division][entity]['state'];
						}
					}
				}
				requestTime = json['time'];
			}
			if (jqXHR.status == 200 || jqXHR.status == 204) {
				//Call update again, if page is still here
				//KRK best way to handle this is likely to check the URL hash
				var urlHash = URLToHash();
				if (urlHash['name'] == request['groups'][0]){
					//While we don't anticipate handling a list of groups, this 
					//may error out if a list was used
					updateList(request, options, requestTime);
				}
			}
		}, // End success
	});  //ajax request
};//loadlistfunction

//Prints all of the navigation items for Ia7
var loadCollection = function(collection_keys) {
	if (collection_keys === undefined) collection_keys = '0';
	var collection_keys_arr = collection_keys.split(",");
	var last_collection_key = collection_keys_arr[collection_keys_arr.length-1];
	var entity_arr = [];
	var entity_sort = collection_json.collections[last_collection_key].children;
	if (entity_sort.length <= 0){
		entity_arr.push("Childless Collection");
	}
	for (var i = 0; i < entity_sort.length; i++){
		var collection = entity_sort[i];
		if (!(collection in collection_json.collections)) continue;
		var link = collection_json.collections[collection].link;
		var icon = collection_json.collections[collection].icon;
		var name = collection_json.collections[collection].name;
		var next_collection_keys = collection_keys + "," + entity_sort[i];
		link = buildLink (link, next_collection_keys);
		if (collection_json.collections[collection].external !== undefined) {
			link = collection_json.collections[collection].external;
		}
		var button_html = "<a link-type='collection' href='"+link+"' class='btn btn-default btn-lg btn-block btn-list' role='button'><i class='fa "+icon+" fa-2x fa-fw'></i>"+name+"</a>";
		entity_arr.push(button_html);
	}
	//loop through array and print buttons
	var row = 0;
	var column = 1;
	for (var i = 0; i < entity_arr.length; i++){
		if (column == 1){
            if (row === 0){
                $('#list_content').html('');
            }
			$('#list_content').append("<div id='buffer"+row+"' class='row top-buffer'>");
			$('#buffer'+row).append("<div id='row" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
		}
		$('#row'+row).append("<div class='col-sm-4'>" + entity_arr[i] + "</div>");
		if (column == 3){
			column = 0;
			row++;
		}
		column++;
	}
};

//Constructs a link, likely should be replaced by HashToURL
function buildLink (link, collection_keys){
	if (link === undefined) {
		link = "#";
	} 
	else if (link.indexOf("#") === -1){
		link = "#request=page&link="+link+"&";
	}
	else {
		link += "&";
	}
	link += "collection_key="+ collection_keys;
	return link;
}

//Outputs a constantly updating print log
var print_log = function(time) {
	if (typeof time === 'undefined'){
		$('#list_content').html("<div id='print_log' class='row top-buffer'>");
		$('#print_log').append("<div id='row_log' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
		$('#row_log').append("<ul id='list'></ul>");
		time = 0;
	}
	$.ajax({
		type: "GET",
		url: "/LONG_POLL?json('print_log','time="+time+",long_poll')",
		dataType: "json",
		success: function( json, statusText, jqXHR ) {
			var requestTime = time;
			if (jqXHR.status == 200) {
				for (var i = (json.print_log.text.length-1); i >= 0; i--){
					var line = String(json.print_log.text[i]);
					line = line.replace(/\n/g,"<br>");
					$('#list').prepend("<li style='font-family:courier, monospace;white-space:pre-wrap;font-size:small;padding-left: 13em;text-indent: -13em;position:relative;'>"+line+"</li>");
				}
				requestTime = json['time'];
			}
			if (jqXHR.status == 200 || jqXHR.status == 204) {
				//Call update again, if page is still here
				//KRK best way to handle this is likely to check the URL hash
				if ($('#row_log').length !== 0){
					//If the print log page is still active request more data
					print_log(requestTime);
				}
			}		
		}
	});
};

//Outputs the list of triggers
var trigger = function() {
	$.ajax({
	type: "GET",
	url: "/sub?json(triggers)",
	dataType: "json",
	success: function( json ) {
		var keys = [];
		for (var key in json.triggers) {
			keys.push(key);
		}
		var row = 0;
		for (var i = (keys.length-1); i >= 0; i--){
			var name = keys[i];
			if (row === 0){
				$('#list_content').html('');
			}
			var dark_row = '';
			if (row % 2 == 1){
				dark_row = 'dark-row';
			}
			$('#list_content').append("<div id='row_a_" + row + "' class='row top-buffer'>");
			$('#row_a_'+row).append("<div id='content_a_" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
			$('#content_a_'+row).append("<div class='col-sm-5 trigger "+dark_row+"'><b>Name: </b><a id='name_"+row+"'>" + name + "</a></div>");
			$('#content_a_'+row).append("<div class='col-sm-4 trigger "+dark_row+"'><b>Type: </b><a id='type_"+row+"'>" + json.triggers[keys[i]].type + "</a></div>");
			$('#content_a_'+row).append("<div class='col-sm-3 trigger "+dark_row+"'><b>Last Run:</b> " + json.triggers[keys[i]].triggered + "</div>");
			$('#list_content').append("<div id='row_b_" + row + "' class='row'>");
			$('#row_b_'+row).append("<div id='content_b_" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
			$('#content_b_'+row).append("<div class='col-sm-5 trigger "+dark_row+"'><b>Trigger:</b> <a id='trigger_"+row+"'>" + json.triggers[keys[i]].trigger + "</a></div>");
			$('#content_b_'+row).append("<div class='col-sm-7 trigger "+dark_row+"'><b>Code:</b> <a id='code_"+row+"'>" + json.triggers[keys[i]].code + "</a></div>");
			$.fn.editable.defaults.mode = 'inline';
			$('#name_'+row).editable({
				type: 'text',
				pk: 1,
				url: '/post',
				title: 'Enter username'
			});
			$('#type_'+row).editable({
				type: 'select',
				pk: 1,
				url: '/post',
				title: 'Select Type',
				source: [{value: 1, text: "Disabled"}, {value: 2, text: "NoExpire"}]
			});
			$('#trigger_'+row).editable({
				type: 'text',
				pk: 1,
				url: '/post',
				title: 'Enter trigger'
			});
			$('#code_'+row).editable({
				type: 'text',
				pk: 1,
				url: '/post',
				title: 'Enter code'
			});
			row++;
		}
	}
	});
};

$(document).ready(function() {
	// Start
	changePage();
	//Watch for future changes in hash
	$(window).bind('hashchange', function() {
		changePage();
	});
	$("#toolButton").click( function () {
		var entity = $("#toolButton").attr('entity');
		console.log(entity);
		$('#optionsModal').modal('show');
		$('#optionsModal').find('.object-title').html(entity + " - Options");
		$('#optionsModal').find('.options-dialog').attr("entity", entity);
		$('#optionsModal').find('#options').html('<ul id="sortable" class="list-group"></ul>');
		for (var i = 0; i <= entity_store[entity].sort_order.length; i++){
			$('#sortable').append('<li class="list-group-item">'+entity_store[entity].sort_order[i]+'</li>');
		}
		$( "#sortable" ).sortable();
        //$( "#sortable" ).disableSelection();
	});
});