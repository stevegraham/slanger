$(document).ready(function() {
  // Configuration for fancy sortable tables for source file groups
  $('.file_list').dataTable({
    "aaSorting": [[ 1, "asc" ]],
    "bPaginate": false,
    "bJQueryUI": true,
    "aoColumns": [
			null,
		  { "sType": "percent" },
			null,
			null,
			null,
			null,
      null
		]
  });
  
  // Syntax highlight all files up front - deactivated
  // $('.source_table pre code').each(function(i, e) {hljs.highlightBlock(e, '  ')});
  
  // Syntax highlight source files on first toggle of the file view popup
  $("a.src_link").click(function() {
    // Get the source file element that corresponds to the clicked element
    var source_table = $($(this).attr('href'));
    
    // If not highlighted yet, do it!
    if (!source_table.hasClass('highlighted')) {
      source_table.find('pre code').each(function(i, e) {hljs.highlightBlock(e, '  ')});
      source_table.addClass('highlighted');
    };
  });
  
  // Set-up of popup for source file views
  $("a.src_link").fancybox({
		'hideOnContentClick': true,
		'centerOnScroll': true,
		'width': '90%',
		'padding': 0,
		'transitionIn': 'elastic'
  });
	
	// Hide src files and file list container after load
  $('.source_files').hide();
  $('.file_list_container').hide();
  
  // Add tabs based upon existing file_list_containers
  $('.file_list_container h2').each(function(){
    var container_id = $(this).parent().attr('id');
    var group_name = $(this).find('.group_name').first().html();
    var covered_percent = $(this).find('.covered_percent').first().html();
    
    $('.group_tabs').append('<li><a href="#' + container_id + '">' + group_name + ' ('+ covered_percent +')</a></li>');
  });

  $('.group_tabs a').each( function() {
    $(this).addClass($(this).attr('href').replace('#', ''));
  });
  
  // Make sure tabs don't get ugly focus borders when active
  $('.group_tabs a').live('focus', function() { $(this).blur(); });
  
  var favicon_path = $('link[rel="shortcut icon"]').attr('href');
  $('.group_tabs a').live('click', function(){
    if (!$(this).parent().hasClass('active')) {
      $('.group_tabs a').parent().removeClass('active');
      $(this).parent().addClass('active');
      $('.file_list_container').hide();
      $(".file_list_container" + $(this).attr('href')).show();
      window.location.href = window.location.href.split('#')[0] + $(this).attr('href').replace('#', '#_');
      
      // Force favicon reload - otherwise the location change containing anchor would drop the favicon...
      // Works only on firefox, but still... - Anyone know a better solution to force favicon on local file?
      $('link[rel="shortcut icon"]').remove();
      $('head').append('<link rel="shortcut icon" type="image/png" href="'+ favicon_path +'" />');
    };
    return false;
  });
  
  if (jQuery.url.attr('anchor')) {
    $('.group_tabs a.'+jQuery.url.attr('anchor').replace('_', '')).click();
  } else {
    $('.group_tabs a:first').click();
  };
  
  $("abbr.timeago").timeago();
  $('#loading').fadeOut();
  $('#wrapper').show();
});
