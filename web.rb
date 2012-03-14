# Pivotal Tracker stats analyzer and information radiator

# Setup external requirements
require 'sinatra'
require 'rubygems'
require 'erb'
require 'yaml'
require 'rexml/document'
require 'bcrypt'

# Require the rest of our application
require './models'
require './pt_api'
require './helpers'
require './core_ext'
require './charts'

# Setup globals
@environment = ENV['RACK_ENV'] || 'development'
$SETTINGS = YAML::load(File.open('./config.yml'))[@environment]
$SETTINGS['bucket_code'] = ENV['BUCKET_CODE'] || $SETTINGS['bucket_code']
$SETTINGS['username'] = ENV['USERNAME'] || $SETTINGS['username']
$SETTINGS['hash_password'] = ENV['HASH_PASSWORD'] || $SETTINGS['hash_password']
$SETTINGS['project_id'] = ENV['PROJECT_ID'].try(:to_i) || $SETTINGS['project_id']
$SETTINGS['project_name'] = ENV['PROJECT_NAME'] || $SETTINGS['project_name']
$SETTINGS['api_token'] = ENV['API_TOKEN'] || $SETTINGS['api_token']

Iteration::SEED = ENV['ITERATION_SEED'].try(:to_time) || $SETTINGS['iteration_seed'].to_time
Iteration::LENGTH = ENV['ITERATION_LENGTH'].try(:to_i) || $SETTINGS['iteration_length']

require './routes'

if $SETTINGS['proxy']=='auto' && ENV['HTTP_PROXY']!=nil
 proxy = URI.parse(ENV['HTTP_PROXY'])
 PtApi::Request::PROXY = Net::HTTP::Proxy(proxy.host,proxy.port)
elsif $SETTINGS['proxy']
 proxy = URI.parse($SETTINGS['proxy'])
 PtApi::Request::PROXY = Net::HTTP::Proxy(proxy.host,proxy.port)
else
  PtApi::Request::PROXY =  Net::HTTP
end

# Register the charts

TimeChart.register(
  :type => 'stacked-area',
  :name => 'chart_iterations_time',
  :title => 'Iteration Ticket States',
  :iteration => Iteration.latest,
  :location => 'c',
  :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected']
  )
Chart.register(
  :type => 'stacked-bar',
  :name => 'chart_iterations2',
  :title => 'Project Ticket States',
  :iterations => [Iteration.all],
  :location => 'c',
  :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected']
)
IterationChart.register(
  :type => 'stacked-area',
  :name => 'chart_all_iterations_time',
  :title => 'Ticket States History',
  :iteration_range => (0..Iteration.latest.number),
  :location => 'ov_a',
  :properties => '"renderOptions": {"defaultAxisStart": 0.5}, "dataOptions": {"zeroShift" : false, "shiftAxis": true}',
  :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected']
)