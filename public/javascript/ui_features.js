(function ($) {
  $(function () {
    // Drawer Controls
    if ($('#open_drawer').length > 0) {
      $('#navigation').children('li').slideToggle(500);
      $('#open_drawer').bind('click', function () {
        $('#navigation').children('li').slideToggle(500);
        if ($('#open_drawer').text() === '↓') {
          $('#open_drawer').text('↑');
        } else {
          $('#open_drawer').text('↓');
        }
      });
    }

    // Content Refresh (Meta Content Refresh is not robust)
    setInterval(function () {window.location.reload(); }, 120000);
  });
//End wrapper
})(jQuery);