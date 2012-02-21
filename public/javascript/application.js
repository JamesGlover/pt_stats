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
        'stacked-bar': {
          renderer: jQuery.jqplot.BarRenderer,
          rendererOptions: {
            showDataLabels: true,
            barMargin: 30,
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
        
        var data =[], series_labels=[], ticks = [], axes={}, stotal = [];
        switch(type) { // Unfortunately chart types take their data inconsistantly.
          
          case 'stacked-bar':
          // jqplot does not provide native support for stacked bar charts in the manner we want. Instead we must adapt the bar chart, which provides series stacking.
          // example: var data = [[2, 6, 7, 10],[7, 5, 3, 4],[14, 9, 3, 8]]; However! each apparent series is actually an axis in terms of recieved data
          // ie.[[start1,start2,start3],[finished1,finished2,finished3]]
          // Furthermore, data need to be manually converted to percentages.
          // 'Series' labels are given in: series:[{label:'a'},{label:'b'},{label:'c'}]
          
          for (s=0; s < series.length; s++) { // For each series
            ticks[s] = series[s][0]; // TODO: Something useful with this
            stotal[s] = 0;
            $.each(series[s][1], function() {stotal[s]+=this;})
            series_labels[s] = {label: axis[i]};
          }
          for (i=0; i < axis.length; i++) { // For each item
            data[i]=[]
            for (s=0; s < series.length; s++) {
              data[i][s]=(series[s][1][i]/stotal[s])*100;
            }
          }

          axes = {
            xaxis: {
              renderer: $.jqplot.CategoryAxisRenderer,
              ticks: ticks
            },
            yaxis: {
              padMax: 0,
              display: false
            }
          }
          break;
          
          case 'pie':
          // Pie and donut example: var data = [['Segment A', 12],['Segment B', 9], ['Segment C', 14]],[['Segment A2', 12],['Segment B2', 9], ['Segment C2', 14]];
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
          stackSeries: true,
          seriesColors: colours,
          grid: { 
            borderWidth: 0,
            shadow: false,
            background: 'transparent',
            drawGridlines: false
          },
          series: series_labels,
          axes: axes,
          title: {
            text: title,
            show: true,
          },
          seriesDefaults: renderers[type],
          legend: {
            show: false
          }
        });
      })
  
    // End Document Read
  });

  //End wrapper
})(jQuery)