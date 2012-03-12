// Pivotal tracker stats analysis
(function ($) {
  //Wrapper
  "use strict";
  //var $ = jQuery;

  $(function () {
    // jQuery Document Ready
    var colours, renderers, options;
    // To keep things consistent we'll read our colour array in from the document itself.
    // Fallback to defaults if we can't find anything.
    colours = [
      $('.created').css('background-color') || '#C9DADA',
      $('.started').css('background-color') || '#E4E4E4',
      $('.finished').css('background-color') || '#3C466F',
      $('.delivered').css('background-color') || '#F0A222',
      $('.accepted').css('background-color') || '#86EC96',
      $('.rejected').css('background-color') || '#FF8995'
    ];

    renderers = {

      // Setup the render types
      'pie': {
        renderOptions: {
          seriesDefaults: {
            renderer: $.jqplot.PieRenderer,
            rendererOptions: {
              showDataLabels: false,
              dataLabels: 'label'
            }
          }
        },
        dataOptions: {
          invertSeries: false,
          absoluteValues: true
        }
      },

      'stacked-bar': {
        renderOptions: {
          seriesDefaults: {
            renderer: $.jqplot.BarRenderer,
            rendererOptions: {
              showDataLabels: true,
              barMargin: 30,
              dataLabels: 'label',
              barWidth: 100
            }
          },
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
        dataOptions: {
          invertSeries: true,
          absoluteValues: false
        }
      },

      'stacked-area': {
        renderOptions: {
          seriesDefaults: {
            fill: true
          },
          axes: {
            xaxis: {
              renderer: $.jqplot.CategoryAxisRenderer,
              min: 0
            },
            yaxis: {
              padMin: 0,
              padMax: 0,
              display: false
            }
          },
          defaultAxisStart: 0
        },
        dataOptions: {
          invertSeries: true,
          absoluteValues: true,
          zeroShift: true
        }
      },

      'default':  { // A Pie!
        renderOptions: {
          seriesDefaults: {
            renderer: $.jqplot.PieRenderer,
            rendererOptions: {
              showDataLabels: false,
              dataLabels: 'label'
            }
          }
        },
        dataOptions: {
          invertSeries: false,
          absoluteValues: true
        }
      }

    };

    options = {
      renderOptions: {
        stackSeries: true,
        seriesColors: colours,
        grid: {
          borderWidth: 0,
          shadow: false,
          background: 'transparent',
          drawGridlines: false
        },
        series: [],
        title: {
          text: null,
          show: true
        },
        legend: {
          show: false
        }
      }
    };

    // Automatically parse chart divs, using the contained tabulated data
    $('.chart').each(function () {

      var name, axis, series, type, data = [], stotal = [], s, i, local_options;

      // Get the data from the document
      if (this.getAttribute('data-chartname') === null) {
        return;
      }

      type = this.getAttribute('data-charttype');
      if (renderers[type] === null) {
        type = 'default';
      }

      name = this.getAttribute('data-chartname');

      local_options = {
        renderOptions: {},
        dataOptions: {}
      };
      $.extend(true, local_options, options, renderers[type], JSON.parse($('#' + name + '_json')[0].textContent)); // Read in the options

      local_options.renderOptions.title.text = $('#' + name + '_title')[0].textContent;

      axis = $('#' + name + '_head').children('.axis_label').map(function () { // Each axis label
        return this.textContent;
      }).get();

      series = $('#' + name + '_body').children('tr').map(function () { // Each series
        var s = [];
        s[0] = $(this).children('th').get(0).textContent;
        // Series name
        s[1] = $(this).children('td').map(function () { //each value
          return parseInt(this.textContent, 10);
        }).get();
        //series data
        return [s];
      }).get();

      // And convert it into a chart...
      if (local_options.dataOptions.invertSeries) {
        // stacked bars etc.
        local_options.renderOptions.axes.xaxis.ticks = [];
        for (s = 0; s < series.length; s += 1) {
          // For each series
          local_options.renderOptions.axes.xaxis.ticks[s] = series[s][0];
          local_options.renderOptions.series[s] = { label: axis[s] };
          if (!local_options.dataOptions.absoluteValues) {
            stotal[s] = 0;
            for (i = 0; i < series[s][1].length; i += 1) {
              stotal[s] += series[s][1][i];
            }
          }
        }

        for (i = 0; i < axis.length; i += 1) {
          // For each item
          data[i] = [];
          for (s = 0; s < series.length; s += 1) {
            if (!local_options.dataOptions.absoluteValues) {
              if (series[s][1][i] !== undefined) {
                data[i][s] = (series[s][1][i] / stotal[s]) * 100;
              }
            } else {
              if (series[s][1][i] !== undefined) {
                data[i][s] = (series[s][1][i]);
              }
            }
          }
          if (local_options.dataOptions.zeroShift) {data[i].unshift(data[i][0]);}
        }

      } else {
        // Pie charts etc.
        for (s = 0; s < series.length; s += 1) {
          // For each series
          data[s] = [];
          for (i = 0; i < axis.length; i += 1) {
            // For each item
            data[s][i] = ([axis[i], series[s][1][i]]);
          }
        }
      }
      
      if (local_options.dataOptions.shiftAxis) {local_options.renderOptions.axes.xaxis.ticks.shift();}
      $.jqplot(name + '_chart', data, local_options.renderOptions);
    });
    
    // Drawer Controls
    if ($('#open_drawer').length > 0) {
      $('#navigation').children('li').slideToggle(500);
      $('#open_drawer').bind('click',function () {
        $('#navigation').children('li').slideToggle(500);
        if ($('#open_drawer').text() == '↓') {
          $('#open_drawer').text('↑')
        } else {
          $('#open_drawer').text('↓');
        }
      });
    }
    
    // Content Refresh (Meta Content Refresh is not robust)
    setInterval(function () {window.location.reload();}, 12000);
    // End Document Read
  });

  //End wrapper
})(jQuery);
