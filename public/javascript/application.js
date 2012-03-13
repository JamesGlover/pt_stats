// Pivotal tracker stats analysis
(function ($) {
  //Wrapper
  "use strict";

  // Chart prototype

  $(function () {
    // jQuery Document Ready
    var colours, renderers, options, Chart;
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

    Chart = function (table) { // The chart prototype
      this.data_table = table;
    };

    Chart.prototype.getData = function () {
      // Get the data from the document
      if (this.data_table.getAttribute('data-chartname') === null) {
        return;
      }

      this.name = this.data_table.getAttribute('data-chartname');
      this.local_options = {
        renderOptions: {},
        dataOptions: {}
      };

      $.extend(true, this.local_options, options, renderers[this.type()], this.json()); // Read in the options
      this.local_options.renderOptions.title.text = $('#' + this.name + '_title')[0].textContent;
      this.axis = this.getAxis();
      this.series = this.getSeries();
    };
    
    Chart.prototype.type = function () {
      var type
      type = this.data_table.getAttribute('data-charttype');
      if (renderers[type] === null) {
        type = 'default';
      }
      return type;
    }
    
    Chart.prototype.scale = function (s) {
      if (!this.local_options.dataOptions.absoluteValues) {
        var stotal = 0;
        for (i = 0; i < this.series[s][1].length; i += 1) {
          stotal += this.series[s][1][i];
        }
        return stotal;
      } else {
        return 100;
      }
    }
    
    Chart.prototype.getAxis = function () {
      return $('#' + this.name + '_head').children('.axis_label').map(function () { // Each axis label
        return this.textContent;
      }).get();
    }
    
    Chart.prototype.getSeries = function () {
      return $('#' + this.name + '_body').children('tr').map(function () { // Each series
        var s = [];
        s[0] = $(this).children('th').get(0).textContent;
        // Series name
        s[1] = $(this).children('td').map(function () { //each value
          return parseInt(this.textContent, 10);
        }).get();
        //series data
        return [s];
      }).get();
    }
    
    Chart.prototype.json = function () {
      return JSON.parse($('#' + this.name + '_json')[0].textContent);
    }

    Chart.prototype.render = function () {
      var data = [], s, i;
      // And convert it into a chart...
      if (this.local_options.dataOptions.invertSeries) {
        // stacked bars etc.
        this.local_options.renderOptions.axes.xaxis.ticks = [];
        for (s = 0; s < this.series.length; s += 1) {
          // For each series
          this.local_options.renderOptions.axes.xaxis.ticks[s] = this.series[s][0];
          this.local_options.renderOptions.series[s] = { label: this.axis[s] };
        }

        for (i = 0; i < this.axis.length; i += 1) {
          // For each item
          data[i] = [];
          for (s = 0; s < this.series.length; s += 1) {
            if (this.series[s][1][i] !== undefined) {
              data[i][s] = (this.series[s][1][i] / this.scale(s) ) * 100;
            }
          }
          if (this.local_options.dataOptions.zeroShift) {data[i].unshift(data[i][0]); }
        }

      } else {
        // Pie charts etc.
        for (s = 0; s < this.series.length; s += 1) {
          data[s] = [];
          for (i = 0; i < this.axis.length; i += 1) {
            data[s][i] = ([this.axis[i], this.series[s][1][i]]);
          }
        }
      }

      if (this.local_options.dataOptions.shiftAxis) {this.local_options.renderOptions.axes.xaxis.ticks.shift(); }
      $.jqplot(this.name + '_chart', data, this.local_options.renderOptions);
    };

    // Automatically parse chart divs, using the contained tabulated data
    $('.chart').each(function () {
      var chart = new Chart(this);
      chart.getData();
      chart.render();
    });

    // End Document Read
  });

//End wrapper
})(jQuery);
