require 'sinatra'
require 'rubygems'
#require "bundler/setup"
#require 'sinatra/activerecord'
require 'erb'
require 'yaml'
require './models'
require './pt_api'
require 'rexml/document'
require 'bcrypt'
require './helpers'

# Setup globals
@environment = ENV['RACK_ENV'] || 'development'
$SETTINGS = YAML::load(File.open('./config.yml'))[@environment]

configure do
  set :raise_exceptions => true;
  #set :public_folder, File.dirname(__FILE__) + '/static'
end

include Helpers

# Display the goods
get '/' do
  protected!
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
      :body => "Your database contains #{incomplete} #{plural} with incomplete information. This can occur if you have not populated the database before connecting the Pivotal Tracker posthooks, or if a ticket creation event was not correctly recieved. You can repair incomplete stories via the <a href='populate'>database population tool</a>."
    }
  end
  
  erb :index, :locals => {
    :project_created => Story.created().length,
    :project_rejected => Story.rejected().length,
    :project_started => Story.started().length,
    :project_finished => Story.finished().length,
    :project_delivered => Story.delivered().length,
    :project_accepted => Story.accepted().length,
    :project_total => Story.count(),
    :messages => messages
    }
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
    messages << PtApi.populate_database($SETTINGS['project_id'],params[:api_key],'all')
  elsif params[:submit] == 'Repair Database'
    # Repair DB
    messages << PtApi.populate_database($SETTINGS['project_id'],params[:api_key],Story.incomplete())
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