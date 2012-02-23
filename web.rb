# Pivotal Tracker stats analyzer and information radiator
# TODO: Clean up the source a bit so that this file is a container
# and initializer.

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
require './charts'

# Setup globals
@environment = ENV['RACK_ENV'] || 'development'
$SETTINGS = YAML::load(File.open('./config.yml'))[@environment]
$SETTINGS['bucket_code'] = ENV['BUCKET_CODE'] || $SETTINGS['bucket_code']
$SETTINGS['username'] = ENV['USERNAME'] || $SETTINGS['username']
$SETTINGS['hash_password'] = ENV['HASH_PASSWORD'] || $SETTINGS['hash_password']
$SETTINGS['project_id'] = ENV['PROJECT_ID'].to_i if ENV['PROJECT_ID']
$SETTINGS['project_name'] = ENV['PROJECT_NAME'] || $SETTINGS['project_name']
$SETTINGS['iteration_seed'] = ENV['ITERATION_SEED'] || $SETTINGS['iteration_seed']
$SETTINGS['iteration_length'] = ENV['ITERATION_LENGTH'].to_i if ENV['ITERATION_LENGTH']
$SETTINGS['api_token'] = ENV['API_TOKEN'] || $SETTINGS['api_token']


## The ap starts
configure do
  set :raise_exceptions => true;
  #set :public_folder, File.dirname(__FILE__) + '/static'
end

include Helpers

# Display the goods
get '/' do
  protected!
  i=current_iteration()
  charts = []
  #charts << Charts.chart_states('pie','chart_iterations','Iteration Ticket States',[i],'c')
  charts << Charts.chart_time_states('stacked-area','chart_iterations_time','Iteration Ticket States',i,'c')
  charts << Charts.chart_states('stacked-bar','chart_iterations2','Project Ticket States',[0],'c')
  #charts << Charts.chart_types('pie','chart_ticket_types','Ticket Types',[0],'c')
  messages = []
  if Story.count() == 0
    messages << {
      :id => 'databaseUnpopulated',
      :classes => 'bad',
      :title => 'Database unpopulated',
      :body => "Your database is currently empty. If you have an existing Pivotal Tracker project, then you will need to import any existing stories. If you do not import existing stories then existing tickets will have incomple information. You can import stories via the <a href='populate'>database population tool</a>."
    }
  end
  incomplete = Story.incomplete.length
  if incomplete > 0
    plural = 'stories'
    plural = 'story' if incomplete == 1 
    messages << {
      :id => 'incompleteStories',
      :classes => 'bad',
      :title => 'Incomplete stories detected',
      :body => ""
    }
  end
  begin
  erb :index, :locals => {
    :project_created => Story.created(0).length,
    :project_rejected => Story.rejected(0).length,
    :project_started => Story.started(0).length,
    :project_finished => Story.finished(0).length,
    :project_delivered => Story.delivered(0).length,
    :project_accepted => Story.accepted(0).length,
    :project_total => Story.total(0).length,
    :iteration=>i,
    :iteration_end=> iteration_end(i),
    :iteration_created => Story.created(i).length,
    :iteration_rejected => Story.rejected(i).length,
    :iteration_started => Story.started(i).length,
    :iteration_finished => Story.finished(i).length,
    :iteration_delivered => Story.delivered(i).length,
    :iteration_accepted => Story.accepted(i).length,
    :iteration_total => Story.total(i).length,
    :messages => messages,
    :charts => charts
    }
  rescue PGError
    messages << {
      :id => 'databaseConnectionIssues',
      :classes => 'bad',
      :title => 'Problems Querying Database',
      :body => "There were problems querying the database"
    }
    erb :index, :locals => {
      :project_created => 0, :project_rejected => 0, :project_started => 0,
      :project_finished => 0, :project_delivered => 0, :project_accepted => 0,
      :project_total => 0, :iteration=>i, :iteration_end=> iteration_end(i),
      :iteration_created => 0, :iteration_rejected => 0, :iteration_started => 0,
      :iteration_finished => 0, :iteration_delivered => 0, :iteration_accepted => 0,
      :iteration_total => 0, :messages => messages, :charts => charts
      }
    end
end

# Display the goods
get '/overview' do
  protected!
  i=current_iteration()
  charts = []
  charts << Charts.chart_iterations_states('stacked-area','chart_all_iterations_time','Ticket States History',(1..i),'a')
  messages = []
  
  begin
  erb :overview, :locals => {
    :iteration=>i,
    :iteration_end=> iteration_end(i),
    :messages => messages,
    :charts => charts
    }
  rescue PGError
    messages << {
      :id => 'databaseConnectionIssues',
      :classes => 'bad',
      :title => 'Problems Querying Database',
      :body => "There were problems querying the database"
    }
    erb :index, :locals => {
      :iteration=>i, :messages => messages, :charts => charts
      }
    end
end

get '/populate' do
  protected!
  
  pop_interface([],$SETTINGS['api_token']);
end

post '/populate' do
  protected!
  messages=[]
  
  if params[:api_key] == ''
    messages << {
      :id => "no_api_key",
      :classes => 'bad',
      :title => 'Error: No API token',
      :body => "No API token was provided; population of the database and repair of incomplete stories requires access to the Pivotal Tracker API. Please provide a Pivotal Tracker API token and try again. The API token can be found on your <a href='https://www.pivotaltracker.com/profile' target='_blank'>Pivotal Tracker profile page</a>."
    }
  elsif params[:submit] == 'Populate Database'
    # Populate DB
    PtApi.populate_database(messages, $SETTINGS['project_id'],params[:api_key],'all')
  elsif params[:submit] == 'Repair Database'
    # Repair DB
    PtApi.populate_database(messages, $SETTINGS['project_id'],params[:api_key],Story.incomplete())
  elsif params[:submit] == 'Flag All Deleted Stories'
    #Todo: Flag all deleted
    PtApi.flag_deleted_items(messages,$SETTINGS['project_id'],params[:api_key],'all')
  elsif params[:submit] == 'Flag Listed Deleted Stories'
    # Todo: Flag Listed deleted
    PtApi.flag_deleted_items(messages,$SETTINGS['project_id'],params[:api_key],params[:del_ids])
  else
    messages << {
      :id => "invalid_post",
      :classes => 'bad',
      :title => 'Error: Invalid post request',
      :body => "Whoops! Something went wrong; the server was unable to work out what you wanted to do.<br/>
      <strong>Submit value:</strong>#{params[:submit]}<br/>
      If you were not using the web interface to update the database, please ensure your request is valid."
    }
  end
  
  pop_interface(messages, params[:api_key]);
end


# Record the details
post "/#{$SETTINGS['bucket_code']}" do
  PtApi.incomming(request.body.read)
end