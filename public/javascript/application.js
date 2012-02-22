// Pivotal tracker stats analysis
(function (jQuery) {
  //Wrapper
  "use strict";
  var $ = jQuery;

  $(function () {
    // jQuery Document Ready
    var colours, renderers;
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
            min: 0,
            max: 7,
            numberTicks: 8
          },
          yaxis: {
            padMin: 0,
            padMax: 0,
            display: false
          }
        },
        defaultAxisStart: 0
      },

      'default': {
        // If the type is invalid, we render a pie.
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
    $('.chart').each(function () {

      var name, title, axis, series, type, data = [], series_labels = [], stotal = [], s, i;

      // Get the data from the document
      if (this.getAttribute('data-chartname') === null) {
        return;
      }
      name = this.getAttribute('data-chartname');
      title = $('#' + name + '_title')[0].textContent;
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
      type = this.getAttribute('data-charttype');

      if (renderers[type] === null) {
        type = 'default';
      }

      // And convert it into a chart...
      if (renderers[type].invertSeries) {
        // stacked bars etc.
        renderers[type].axes.xaxis.ticks = [];
        for (s = 0; s < series.length; s += 1) {
          // For each series
          renderers[type].axes.xaxis.ticks[s] = series[s][0];
          series_labels[s] = {
            label: axis[s]
          };
          if (!renderers[type].absoluteValues) {
            stotal[s] = 0;
            for (i = 0; i < series[s][1].length; i += 1) {
              stotal[s] += series[s][1][i];
            }
          }
        }
        //renderers[type].axes.xaxis.ticks.unshift("...")
        for (i = 0; i < axis.length; i += 1) {
          // For each item
          data[i] = [];
          for (s = 0; s < series.length; s += 1) {
            if (!renderers[type].absoluteValues) {
              if (series[s][1][i] !== null) {
                data[i][s] = (series[s][1][i] / stotal[s]) * 100;
              }
            } else {
              if (series[s][1][i] !== null) {
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

      $.jqplot(name + '_chart', data, {
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
          show: true
        },
        seriesDefaults: renderers[type].seriesDefaults,
        legend: {
          show: false
        },
        defaultAxisStart: renderers[type].defaultAxisStart
      });
    });

    // End Document Read
  });

  //End wrapper
})(jQuery);
