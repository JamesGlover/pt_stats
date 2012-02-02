require 'sinatra'
require 'rubygems'
#require "bundler/setup"
#require 'sinatra/activerecord'
require 'erb'
require 'yaml'
require './models'
require './pt_api'
require 'rexml/document'

configure do
  set :raise_exceptions => true;
end

helpers do

  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [$SETTINGS['username'],$SETTINGS['password']]
  end

end

# Setup globals
$SETTINGS = YAML::load(File.open('./config.yml'))

# Display the goods
get '/' do
  protected!
  erb :index, :locals => {
    :project_created => Story.created().length,
    :project_started => Story.started().length,
    :project_finished => Story.finished().length,
    :project_delivered => Story.delivered().length,
    :project_accepted => Story.accepted().length,
    :project_total => Story.count()
    }
end

get '/setup' do
  protected!
  erb :setup, :locals => {
    
  }
end

# Record the details
post '/' do
  xml = request.body.read
  return nil if xml == ''
  data = REXML::Document.new(xml)
  return nil if data.root == nil || data.root.name != 'activity'
  begin
    event_type = data.elements["activity/event_type"].text
    
    date = DateTime.parse(data.elements["activity/occurred_at"].text)
    data.elements.each("activity/stories/story") do |rec_story|

      # For each story: Should only be one
      ticket_id = rec_story.elements["id"].text
      db_story = Story.find_by_ticket_id(ticket_id)
      if event_type =='story_create'
        if db_story == nil # If out story doesn't exist, create it
          db_story = Story.create!(
          :ticket_id => ticket_id,
          :name => rec_story.elements["name"].text,
          :created => date,
          :ticket_type => rec_story.elements["story_type"].text
          )
        else # Story already exists, this shouldn't ever really fire,
             # but if tickets end up comming in the wrong order, it might be needed
          db_story.created = date
          db_story.save
        end
      elsif event_type == 'story_update'
        if db_story == nil
          db_story = PtApi.fetch_story(ticket_id)
        end
        new_state = rec_story.elements["current_state"].text
        db_story.update_state(new_state,data.elements["activity/occurred_at"].text)
      end
    end
  rescue
    puts "XML Parsing Failed"
    return nil
  end  
  return nil
end