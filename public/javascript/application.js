// Pivotal tracker stats analysis
(function (jQuery) {
  //Wrapper
  "use strict";
  var $ = jQuery;

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
            renderer: jQuery.jqplot.PieRenderer,
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
            renderer: jQuery.jqplot.BarRenderer,
            rendererOptions: {
              showDataLabels: true,
              barMargin: 30,
              dataLabels: 'label'
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
              min: 0,
              //max: 7,
              //numberTicks: 8
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
          absoluteValues: true
        }
      },

      'default':  { // A Pie!
        renderOptions: {
          seriesDefaults: {
            renderer: jQuery.jqplot.PieRenderer,
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
    };

    // Automatically parse chart divs, using the contained tabulated data
    $('.chart').each(function () {

      var name, axis, series, type, data = [], series_labels = [], stotal = [], s, i, local_options;

      
      // Get the data from the document
      if (this.getAttribute('data-chartname') === null) {
        return;
      }
      
      type = this.getAttribute('data-charttype');
      if (renderers[type] === null) {
        type = 'default';
      }
      
      var local_options = jQuery.extend(renderers[type].renderOptions, options);
      
      name = this.getAttribute('data-chartname');
      local_options.title.text = $('#' + name + '_title')[0].textContent;
      
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
      if (renderers[type].dataOptions.invertSeries) {
        // stacked bars etc.
        local_options.axes.xaxis.ticks = [];
        for (s = 0; s < series.length; s += 1) {
          // For each series
          local_options.axes.xaxis.ticks[s] = series[s][0];
          local_options.series[s] = { label: axis[s] };
          if (!renderers[type].dataOptions.absoluteValues) {
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
            if (!renderers[type].dataOptions.absoluteValues) {
              if (series[s][1][i] !== undefined) {
                data[i][s] = (series[s][1][i] / stotal[s]) * 100;
              }
            } else {
              if (series[s][1][i] !== undefined) {
                data[i][s] = (series[s][1][i]);
              }
            }
          }
          data[i].unshift(data[i][0]);
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

      $.jqplot(name + '_chart', data, local_options);
    });

    // End Document Read
  });

  //End wrapper
})(jQuery);
