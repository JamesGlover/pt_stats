// Pivotal tracker stats analysis

(function (jQuery) { //Wrapper
  
  $=jQuery
  
  $( function(){ // jQuery Document Ready
    
      // To keep things consistent we'll read our colour array in from the document itself.
      // Fallback to defaults if we can't find anything.
      var colours= [$('.created').css( 'background-color' )||'#C9DADA',
      $('.started').css( 'background-color' )||'#E4E4E4',
      $('.finished').css( 'background-color' )||'#3C466F',
      $('.delivered').css( 'background-color' )||'#F0A222',
      $('.accepted').css( 'background-color' )||'#86EC96',
      $('.rejected').css( 'background-color' )||'#FF8995']
      
      var renderers = { // Setup the render types
        'pie': {
          renderer: jQuery.jqplot.PieRenderer,
          rendererOptions: {
            showDataLabels: true,
            dataLabels: 'label'
          }
        },
        'default': { // If the type is invalid, we render a pie.
          renderer: jQuery.jqplot.PieRenderer,
          rendererOptions: {
            showDataLabels: true,
            dataLabels: 'label'
          }
        }
       
      };
      
      // Automatically parse chart divs, using the contained tabulated data
      $('.chart').each( function(i,chart){
        
        // Get the data from the document
        if (chart.getAttribute('data-chartname') == null) {return}
        var name = chart.getAttribute('data-chartname')
        var title = $('#'+name+'_title')[0].textContent
        var axis = $('#'+name+'_head').children('.axis_label').map(function(i,label){ return label.textContent }).get()
        var series = $('#'+name+'_body').children('tr').map( function(i,series) {
          var s = []
          s[0]=$(series).children('th').get(0).textContent // Series name
          s[1]=$(series).children('td').map(function(i,v){return parseInt(v.textContent);}).get() //series data
          return [s]
        }).get();
        var type = chart.getAttribute('data-charttype')
        if (renderers[type]==null) {type='default'}
        
        // And convert it into a chart
        
        // Pie and donut example: var data = [['Segment A', 12],['Segment B', 9], ['Segment C', 14]],[['Segment A2', 12],['Segment B2', 9], ['Segment C2', 14]];
        var data =[]
        switch(type) { // Unfortunately chart types take their data inconsistantly.
          
          case 'pie':
          default:
            for (s=0; s<series.length; s++) { // For each series
              var values =[]
              for (i=0; i<axis.length; i++) { // For each item
                values[i]=([axis[i],series[s][1][i]]);
              }
              data[s]=values;
            }
          };
        
        $.jqplot(name+'_chart', data, {
          seriesColors: colours,
          grid: { 
            borderWidth: 0,
            shadow: false,
            background: 'transparent'
          },
          title: {
            text: title,
            show: true,
          },
          seriesDefaults: renderers[type],
          legend: { show:false }
              });
      })
  
    // End Document Read
  });

  //End wrapper
})(jQuery)