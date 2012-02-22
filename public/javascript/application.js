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
          seriesDefaults: {
            renderer: jQuery.jqplot.PieRenderer,
            rendererOptions: {
              showDataLabels: false,
              dataLabels: 'label'
            }
          },
          invertSeries: false,
          absoluteValues: true
        },
        'stacked-bar': {
          seriesDefaults: {
            renderer: jQuery.jqplot.BarRenderer,
            rendererOptions: {
              showDataLabels: true,
              barMargin: 30,
              dataLabels: 'label'
            }
          },
          invertSeries: true,
          absoluteValues: false,
          axes: {
            xaxis: {
              renderer: $.jqplot.CategoryAxisRenderer
            },
            yaxis: {
              padMin: 0,
              padMax: 0,
              display: false
            }
          }
        },
        'stacked-area': {
          seriesDefaults: {
            fill: true
          },
          invertSeries: true,
          absoluteValues: true,
          axes: {
            xaxis: {
              renderer: $.jqplot.CategoryAxisRenderer,
              min:0,
              max:7,
              numberTicks:8
            },
            yaxis: {
              padMin: 0,
              padMax: 0,
              display: false
            }
          },
          defaultAxisStart: 0
        },
        'default': { // If the type is invalid, we render a pie.
          seriesDefaults: {
            renderer: jQuery.jqplot.PieRenderer,
            rendererOptions: {
              showDataLabels: false,
              dataLabels: 'label'
            }
          },
          invertSeries: false,
          absoluteValues: true
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
        
        // And convert it into a chart...
        
        var data =[], series_labels=[], axes={}, stotal = [];
        
        if (renderers[type].invertSeries) { // stacked bars etc.
          renderers[type].axes.xaxis.ticks = []
          for (s=0; s < series.length; s++) { // For each series
            renderers[type].axes.xaxis.ticks[s] = series[s][0];
            series_labels[s] = {label: axis[s]};
            if (!renderers[type].absoluteValues) {
              stotal[s] = 0;
              $.each(series[s][1], function() {stotal[s]+=this;})
            }  
          }
          //renderers[type].axes.xaxis.ticks.unshift("...")
          for (i=0; i < axis.length; i++) { // For each item
            data[i] = []
            for (s=0; s < series.length; s++) {
              if (!renderers[type].absoluteValues) {
                if (series[s][1][i] != null) {data[i][s]=(series[s][1][i]/stotal[s])*100;}
              } else {
                if (series[s][1][i] != null) {data[i][s]=(series[s][1][i]);}
              }
            }
            data[i].unshift(data[i][0])
          }
  
        } else { // Pie charts etc.
          for (s=0; s<series.length; s++) { // For each series
            data[s] = []
            for (i=0; i<axis.length; i++) { // For each item
              data[s][i]=([axis[i],series[s][1][i]]);
            }
          }
        }
        
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
          axes: renderers[type].axes,
          title: {
            text: title,
            show: true,
          },
          seriesDefaults: renderers[type].seriesDefaults,
          legend: {
            show: false
          },
          defaultAxisStart: renderers[type].defaultAxisStart
        });
      })
  
    // End Document Read
  });

  //End wrapper
})(jQuery)