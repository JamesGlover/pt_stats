
helpers do
  include SinatraHelpers
end

# Display the goods
get '/' do
  protected!
  i=Iteration.current
  charts = []
  charts << Charts.chart_time_states(
    :type => 'stacked-area',
    :name => 'chart_iterations_time',
    :title => 'Iteration Ticket States',
    :iteration => i,
    :location => 'c',
    :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected']
    )
  charts << Charts.simple(
    :type => 'stacked-bar',
    :name => 'chart_iterations2',
    :title => 'Project Ticket States',
    :iterations => [Iteration.all],
    :location => 'c',
    :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected']
  )
  messages = []
  if Story.count() == 0
    Message.new({
      :id => 'databaseUnpopulated',
      :classes => 'bad',
      :title => 'Database unpopulated',
      :body => "Your database is currently empty. If you have an existing Pivotal Tracker project, then you will need to import any existing stories. If you do not import existing stories then existing tickets will have incomple information. You can import stories via the <a href='populate'>database population tool</a>."
    })
  end
  incomplete = Story.incomplete.length
  if incomplete > 0
    plural = 'stories'
    plural = 'story' if incomplete == 1 
    Message.new({
      :id => 'incompleteStories',
      :classes => 'bad',
      :title => 'Incomplete stories detected',
      :body => ""
    })
  end
  begin
    erb :index, :locals => {
      :project_created => Story.created(Iteration.all).length,
      :project_rejected => Story.rejected(Iteration.all).length,
      :project_started => Story.started(Iteration.all).length,
      :project_finished => Story.finished(Iteration.all).length,
      :project_delivered => Story.delivered(Iteration.all).length,
      :project_accepted => Story.accepted(Iteration.all).length,
      :project_total => Story.total(Iteration.all).length,
      :iteration=>i.number,
      :iteration_end=> i.end,
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
    Message.new({
      :id => 'databaseConnectionIssues',
      :classes => 'bad',
      :title => 'Problems Querying Database',
      :body => "There were problems querying the database"
    })
    erb :index, :locals => {
      :project_created => 0, :project_rejected => 0, :project_started => 0,
      :project_finished => 0, :project_delivered => 0, :project_accepted => 0,
      :project_total => 0, :iteration=>i, :iteration_end=> i.iteration.end,
      :iteration_created => 0, :iteration_rejected => 0, :iteration_started => 0,
      :iteration_finished => 0, :iteration_delivered => 0, :iteration_accepted => 0,
      :iteration_total => 0, :messages => messages, :charts => charts
    }
  end
end

# Display the goods
get '/overview' do
  protected!
  i=Iteration.current
  charts = []
  charts << Charts.chart_iterations_states(
    :type => 'stacked-area',
    :name => 'chart_all_iterations_time',
    :title => 'Ticket States History',
    :iteration_range => (0..i.number),
    :location => 'a',
    :properties => '"renderOptions": {"defaultAxisStart": 0.5}, "dataOptions": {"zeroShift" : false, "shiftAxis": true}',
    :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected']
  )
  messages = []

  begin
    erb :overview, :locals => {
      :iteration=>i.number,
      :iteration_end=> i.end,
      :messages => messages,
      :charts => charts
    }
  rescue PGError
    Message.new({
      :id => 'databaseConnectionIssues',
      :classes => 'bad',
      :title => 'Problems Querying Database',
      :body => "There were problems querying the database"
    })
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
    Message.new({
      :id => "no_api_key",
      :classes => 'bad',
      :title => 'Error: No API token',
      :body => "No API token was provided; population of the database and repair of incomplete stories requires access to the Pivotal Tracker API. Please provide a Pivotal Tracker API token and try again. The API token can be found on your <a href='https://www.pivotaltracker.com/profile' target='_blank'>Pivotal Tracker profile page</a>."
    })
  elsif params[:submit] == 'Populate Database'
    req = PtApi::PopulateDb.new($SETTINGS['project_id'],params[:api_key],'all').do
  elsif params[:submit] == 'Repair Database'
    req = PtApi::PopulateDb.new($SETTINGS['project_id'],params[:api_key],Story.incomplete()).do
  elsif params[:submit] == 'Flag All Deleted Stories'
    req = PtApi::FlagDeleted.new($SETTINGS['project_id'],params[:api_key],'all').do
  elsif params[:submit] == 'Flag Listed Deleted Stories'
    req = PtApi::FlagDeleted.new($SETTINGS['project_id'],params[:api_key],params[:del_ids].split(',')).do
  else
    Message.new({
      :id => "invalid_post",
      :classes => 'bad',
      :title => 'Error: Invalid post request',
      :body => "Whoops! Something went wrong; the server was unable to work out what you wanted to do.<br/>
      <strong>Submit value:</strong>#{params[:submit]}<br/>
      If you were not using the web interface to update the database, please ensure your request is valid."
    })
  end

  pop_interface(messages, params[:api_key]);
end


# Record the details
post "/#{$SETTINGS['bucket_code']}" do
  PtApi.incomming(request.body.read)
end