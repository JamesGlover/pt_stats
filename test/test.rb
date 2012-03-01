ENV['RACK_ENV'] = 'test'

if ARGV.include?('--clear')
  $CLEAR = true
end

if ARGV.include?('--no-api')
  $NO_API = true
  puts "Remote API calls will not be tested."
end

require 'rubygems'
require './web'
require './helpers'
require 'test/unit'
require 'rack/test'
require './test/test_helpers'

$SETTINGS['api_token'] = ARGV[ARGV.index('-a')+1] || $SETTINGS['api_token']

if $SETTINGS['api_token'] != nil
  puts "Using API key: #{$SETTINGS['api_token']}"
else
  puts "No API key provided. Either edit /config.yml or provide the argument '-a APIKEYHERE'"
end

if Story.count > 0
  if $CLEAR
    Story.destroy_all
  else
    puts "WARNING! Database already populated with test entry"
    puts "Use -- --clear to automatically remove tickets"
    puts "Terminating"
    Process::exit
  end
end

class ServerTests < Test::Unit::TestCase

  include Rack::Test::Methods
  include ::TestHelpers
  
  def setup
    Message.each! {|m| }
  end

  def app
    Sinatra::Application
  end

  def test_without_authentication
    get '/'
    assert_equal 401, last_response.status
  end

  def test_with_bad_credentials
    authorize 'admin', 'not the password'
    get '/'
    assert_equal 401, last_response.status
  end

  def test_with_proper_credentials
    authorize 'admin', 'admin'
    get '/'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Created')
  end

  def test_our_server_works
    authorize 'admin', 'admin'
    get '/'
    assert last_response.ok?
    get '/overview'
    assert last_response.ok?
    assert last_response.body.include?("Test Project"), last_response.body
    get '/populate'
    assert last_response.ok?
        assert last_response.body.include?("Test Project")
  end

  def test_return_includes_template
    authorize 'admin', 'admin'
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Created')
    assert last_response.body.include?('Rejected')
    assert last_response.body.include?('Started')
    assert last_response.body.include?('Finished')
    assert last_response.body.include?('Delivered')
    assert last_response.body.include?('Accepted') 
    assert last_response.body.include?('Total')
  end

  def test_page_title_is_project
    authorize 'admin', 'admin'
    get '/'
    assert last_response.ok?
    assert last_response.body.include?($SETTINGS["project_name"])
  end

  def test_post_requests_do_not_return_template
    post '/bucket'
    assert_equal '', last_response.body
    assert Message.count==0
  end  

  def test_story_totals_returns_stories_in_state
    provide_stories
    authorize 'admin', 'admin'
    get '/'
    assert last_response.ok?
    assert last_response.body.include?("<td id=\"project_created\" class=\"project created half\">1</td>")
    assert last_response.body.include?("<td id=\"project_rejected\" class=\"project rejected half\">0</td>")
    assert last_response.body.include?("<td id=\"project_started\" class=\"project started\" rowspan=2>2</td>")
    assert last_response.body.include?("<td id=\"project_finished\" class=\"project finished\" rowspan=2>2</td>")
    assert last_response.body.include?("<td id=\"project_delivered\" class=\"project delivered\" rowspan=2>1</td>")
    assert last_response.body.include?("<td id=\"project_accepted\" class=\"project accepted\" rowspan=2>3</td>")
    assert last_response.body.include?("<td id=\"project_total\" class=\"project total\" rowspan=2>9</td>")
  end

  def test_post
    post '/bucket','test'
    assert_equal '', last_response.body
    assert Message.count==0
  end
  
  def test_crash_post
    post '/bucket',"<invalid></>"
    assert_equal '', last_response.body
    assert Message.count==0, "Failing: #{Message.render_all}"
  end

  def test_link_to_populate_page_when_database_empty
    authorize 'admin', 'admin'
    get '/'
    assert_equal 200, last_response.status
    assert last_response.body.include?("<a href='populate'>")
  end
  
  def test_scan_for_all_deleted_stories_via_interface
    return nil if $NO_API
    provide_stories
    Story.create!(:ticket_id=>$SETTINGS["test_ticket_id"])
    Story.create!(:ticket_id=>24421565)
    authorize 'admin', 'admin'
    post '/populate', {:submit => 'Flag All Deleted Stories', :del_ids=>"92,333,123", :api_key=>$SETTINGS['api_token']}
    assert Story.find_last_by_ticket_id(2).deleted?
    assert Story.find_last_by_ticket_id(4).deleted?
    assert Story.find_last_by_ticket_id(9).deleted?
    assert !Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"]).deleted?
  end

  def test_scan_for_specific_deleted_stories_via_interface
    return nil if $NO_API
    provide_stories
    Story.create(:ticket_id=>$SETTINGS["test_ticket_id"])
    authorize 'admin', 'admin'
    post '/populate', {:submit => 'Flag Listed Deleted Stories', :del_ids=>"2,4,#{$SETTINGS["test_ticket_id"]}", :api_key=>$SETTINGS['api_token']}
    assert Story.find_last_by_ticket_id(2).deleted?
    assert Story.find_last_by_ticket_id(4).deleted?
    assert !Story.find_last_by_ticket_id(9).deleted?
    assert !Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"]).deleted?
  end

  def teardown
    Story.delete_all
  end

end

class XmlTests < Test::Unit::TestCase
  
  include ::TestHelpers

  def setup
    Message.each! {|m| }
  end
  
  def test_changes_to_story_update_handle_edits_with_rejects
    story_a = Story.create!(:ticket_id=>1, :name=>"Replace this", :ticket_type=>'feature', :created=>previous_iteration(0).to_time, :started=>previous_iteration(1).to_time,
    :rejected=>previous_iteration(3).to_time )
    story_b = Story.create!(:ticket_id=>1, :name=>"Replace this", :ticket_type=>'feature', :created=>previous_iteration(0).to_time, :started=>previous_iteration(5).to_time )
    assert_equal("Replace this",story_b.name)
    assert_equal('feature',story_b.ticket_type)
    assert_equal(previous_iteration(0).to_time, story_b.created)
    assert_equal('started',story_b.state.name)
    assert_equal("Replace this",story_a.name)
    assert_equal('feature',story_a.ticket_type)
    assert_equal(previous_iteration(0).to_time, story_a.created)
    assert_equal('rejected',story_a.state.name)
    File.open("./test/xml/update1.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story_a.reload
    story_b.reload
    assert_equal("Replace this",story_b.name)
    assert_equal("Replace this",story_a.name)
    assert_equal('feature',story_a.ticket_type)
    assert_equal('bug',story_b.ticket_type)
    assert_equal(previous_iteration(0).to_time, story_b.created)
    assert_equal(previous_iteration(0).to_time, story_a.created)
    assert_equal('started',story_b.state.name)
    assert_equal('rejected',story_a.state.name)
    File.open("./test/xml/update2.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story_a.reload
    story_b.reload
    assert_equal("With a new name",story_b.name)
    assert_equal('bug',story_b.ticket_type)
    assert_equal(previous_iteration(0).to_time ,story_b.created)
    assert_equal('started',story_b.state.name)
    assert_equal("Replace this",story_a.name)
    assert_equal('feature',story_a.ticket_type)
    assert_equal(previous_iteration(0).to_time ,story_a.created)
    assert_equal('rejected',story_a.state.name)
    # And check counts
    assert_equal(0,Story.features(Iteration.all).length, "With: #{Story.features(Iteration.all)}")
    assert_equal(1,Story.bugs(Iteration.all).length,"With: #{Story.bugs(Iteration.all)}" )
  end

  def test_update_stories_updates
    File.open("./test/xml/start2.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    incomplete = Story.incomplete
    assert incomplete.include?(2)
    story = Story.find_last_by_ticket_id(2)
    story.ticket_id=$SETTINGS["test_ticket_id"]
    story.save
    assert_equal('Unknown story',story.name)
    incomplete = Story.incomplete
    return nil if $NO_API
    PtApi::PopulateDb.new($SETTINGS['project_id'],$SETTINGS['api_token'],incomplete).do
    story.reload
    assert_equal($SETTINGS['test_ticket_name'], story.name)
  end
  
  def test_calls_for_multiple_stories
    # TODO: Update to take into account test project changes
    
  end

  def test_post_calls_delete_stories
    provide_stories
    File.open("./test/xml/delete.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story = Story.find_last_by_ticket_id(3)
    story.deleted?
  end

  def test_odd_bug_a
    File.open("./test/xml/odd_bug.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
  end

  def test_odd_bug
    Story.create!(:id => 12, :ticket_id => 24579125, :name => "new story", :created => "2012-02-07 16:43:45", :rejected => "2012-02-07 16:43:45", :ticket_type => "feature")
    Story.create!(:id => 17, :ticket_id => 24579125, :name => "new story", :created => "2012-02-07 16:43:45", :started=> "2012-02-09 10:50:16", :rejected => "2012-02-09 10:50:46", :ticket_type => "feature")
    File.open("./test/xml/odd_bug.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    assert_equal(0,Story.rejected(Iteration.all).length)
    assert_equal(3,Story.count)
    assert_equal(1,Story.started(Iteration.all).length)
  end

  def test_select_latest
    Story.create!(:id => 12, :ticket_id => 24579125, :name => "new story", :created => "2012-02-07 16:43:45", :rejected => "2012-02-07 16:43:45", :ticket_type => "feature")
    Story.create!(:id => 17, :ticket_id => 24579125, :name => "newer story", :created => "2012-02-07 16:43:45", :started=> "2012-02-09 10:50:16", :rejected => "2012-02-09 10:50:46", :ticket_type => "feature")
    File.open("./test/xml/odd_bug.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    n = Story.find_last_by_ticket_id(24579125)
    assert_equal(0,Story.rejected(Iteration.all).length)
    assert_equal(3,Story.count)
    assert_equal(1,Story.started(Iteration.all).length)
    assert_equal("newer story", n.name)
    assert_equal('started',n.state.name)
  end

  def test_unstarting_works_with_xml
    story = Story.create!(
    :ticket_id => 1,
    :created => current_iteration(0),
    :started => current_iteration(1))
    assert_counts(0,[0,1,0,0,0,0,1,1])
    assert_counts(4,[0,1,0,0,0,0,1,1])

    File.open("./test/xml/unstarted.xml") do |file|
      PtApi.incomming(file.read)
    end

    assert_counts(0,[1,0,0,0,0,0,1,2])
    assert_counts(4,[1,0,0,0,0,0,0,2])
    story = Story.find_last_by_ticket_id(1)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse(current_iteration(0)),story.ori_created)
    assert_equal(Time.parse(current_iteration(2)),story.created)

  end

  def test_specific_failure_with_xml
    Story.create!( :id => 45, :ticket_id => 25105815, :name => "Start, then put back on ice", :created => "2012-02-17 10:32:07", :started=> "2012-02-17 10:32:37",
    :finished=> nil, :delivered=> nil, :accepted=> "2012-02-17 11:39:00", :rejected=> nil, :deleted=> nil, :ticket_type=> "chore")
    Story.create!( :id => 46, :ticket_id => 25105815, :name => "Start, then put back on ice", :created => nil, :started=> "2012-02-17 10:50:32",
    :finished=> nil, :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "chore")
    story = Story.create!( :id => 50, :ticket_id => 25105815, :name => "Start, then put back on ice", :created => nil, :started=> "2012-02-17 11:37:49",
    :finished=> nil, :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "chore")

    assert 5.iteration.start < Time.parse("2012-02-17 11:37:49")
    assert 5.iteration.end > Time.parse("2012-02-17 11:37:49")
    assert_counts(0,[0,1,0,0,0,0,1,3])
    assert_counts(5,[0,1,0,0,0,0,1,3])

    File.open("./test/xml/specifictest.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0

    assert_counts(0,[0,0,0,0,1,0,1,3])
    assert_counts(5,[0,0,0,0,1,0,1,3])

    story.update_state('accepted','2012/02/17 11:39:00 UTC')
    assert_counts(0,[0,0,0,0,1,0,1,3])
    assert_counts(5,[0,0,0,0,1,0,1,3])
  end

  def test_create_events_create_a_story
    File.open("./test/xml/create.xml") do |file|
      PtApi.incomming(file.read)
    end
    story = Story.find_last_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse('2012/01/31 13:37:51 UTC'),story.created)
  end

  def test_update_events_update_a_story
    File.open("./test/xml/create.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story = Story.find_last_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse('2012/01/31 13:37:51 UTC'),story.created)

    File.open("./test/xml/start.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story.reload
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('started',story.state.name)
    assert_equal(Time.parse('2012/01/31 13:37:51 UTC'),story.created)
    assert_equal(Time.parse('2012/02/01 11:05:51 UTC'),story.started)
    File.open("./test/xml/accepted.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story.reload
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('accepted',story.state.name)
    assert_equal(Time.parse('2012/01/31 13:37:51 UTC'),story.created)
    assert_equal(Time.parse('2012/02/01 11:05:51 UTC'),story.started)
    assert_equal(Time.parse('2012/02/01 12:03:36 UTC'),story.accepted)
  end

  def test_other_events_have_no_effect
    File.open("./test/xml/create.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story = Story.find_last_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse('2012/01/31 13:37:51 UTC'),story.created)

    File.open("./test/xml/note.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story = Story.find_last_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse('2012/01/31 13:37:51 UTC'),story.created)
  end

  def test_activities_can_be_used_for_population
    File.open("./test/xml/activities.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story = Story.find_last_by_ticket_id(24220815)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('accepted',story.state.name)
    assert_equal(Time.parse('2012/01/31 13:37:51 UTC'),story.created)
    assert_equal(Time.parse('2012/02/01 12:03:36 UTC'),story.accepted)
    assert Story.find_by_ticket_id(24421623).id > Story.find_by_ticket_id(24421609).id
  end

  def test_graphing_functions
    File.open("./test/xml/activities.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    total_states = Charts.simple(
      :type => 'stacked-bar',
      :name => 'chart_id',
      :title => 'Title',
      :iterations => [Iteration.all],
      :location=> 'a',
      :properties => 'json',
      :axis =>['Created','Started','Finished','Delivered','Accepted','Rejected'])
    single_states = Charts.simple(
      :type => 'stacked-bar',
      :name => 'chart_id',
      :title => 'Title',
      :iterations => [4.iteration],
      :location => 'a',
      :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected'],
      :properties => 'json')
    single_types = Charts.simple(
      :type => 'stacked-bar',
      :name => 'chart_id',
      :title => 'Title',
      :iterations => [4.iteration],
      :location => 'a',
      :axis => ['Bugs','Features','Chores','Releases'],
      :properties => 'json')
    times_states = Charts.chart_time_states(
      :type => 'stacked-area',
      :name => 'chart_id',
      :title => 'Title',
      :iteration => 3.iteration,
      :location => 'a',
      :properties => 'json',
      :axis =>['Created','Started','Finished','Delivered','Accepted','Rejected'])
    iteration_states = Charts.chart_iterations_states(
      :type => 'stacked-area',
      :name => 'chart_id',
      :title => 'Title',
      :iteration_range => (0..4),
      :location => 'a',
      :properties => 'json',
      :axis =>['Created','Started','Finished','Delivered','Accepted','Rejected'])
    assert_equal({:location=>"a",
     :type=>"stacked-bar",
     :name=>"chart_id",
     :title=>"Title",
     :axis=> ["Created", "Started", "Finished", "Delivered", "Accepted", "Rejected"],
     :series=>[["Project", [1, 1, 1, 1, 1, 1]]],
     :properties=>"json"},total_states.reject {|k,v| k==:iterations})
    assert_equal({:location=>"a",
     :type=>"stacked-bar",
     :name=>"chart_id",
     :title=>"Title",
     :axis=> ["Created", "Started", "Finished", "Delivered", "Accepted", "Rejected"],
     :series=>[["Iteration 4", [0, 1, 1, 1, 0, 1]]],
     :properties=>"json"},single_states.reject {|k,v| k==:iterations})
    assert_equal( {:location=>"a",
      :type=>"stacked-bar",
      :name=>"chart_id",
      :title=>"Title",
      :axis=> ['Bugs','Features','Chores','Releases'],
      :series=>[["Iteration 4", [0, 4, 0, 0 ]]],
      :properties=>"json"},single_types.reject {|k,v| k==:iterations})
    assert_equal(  {:location=>"a",
       :type=>"stacked-area",
       :name=>"chart_id",
       :title=>"Title",
       :axis=> ["Created", "Started", "Finished", "Delivered", "Accepted", "Rejected"],
       :series=>[
         ["Day 1", [0, 0, 0, 0, 0, 0]],
         ["Day 2", [2, 0, 0, 0, 0, 0]],
         ["Day 3", [0, 1, 0, 0, 1, 0]],
         ["Day 4", [0, 1, 0, 0, 1, 0]],
         ["Day 5", [1, 1, 1, 1, 1, 1]],
         ["Day 6", [1, 1, 1, 1, 1, 1]],
         ["Day 7", [1, 1, 1, 1, 1, 1]]],
       :properties=>"json"},times_states.reject {|k,v| k==:iteration})
    assert_equal(   {:location=>"a",
        :type=>"stacked-area",
        :name=>"chart_id",
        :title=>"Title",
        :axis=> ["Created", "Started", "Finished", "Delivered", "Accepted", "Rejected"],
        :series=>[
          ["Iteration 0", [0, 0, 0, 0, 0, 0]],
          ["Iteration 1", [0, 0, 0, 0, 0, 0]],
          ["Iteration 2", [0, 0, 0, 0, 0, 0]],
          ["Iteration 3", [1, 1, 1, 1, 1, 1]],
          ["Iteration 4", [1, 1, 1, 1, 1, 1]]],
        :properties=>"json"},iteration_states.reject {|k,v| k==:iteration_range})
  end

  def test_uncreated_tickets_get_default_data
    File.open("./test/xml/start2.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story = Story.find_last_by_ticket_id(2)
    assert_equal('Unknown story',story.name)
    assert_equal('started',story.state.name)
    assert_equal(nil,story.created)
    assert_equal(Time.parse('2012/02/01 14:56:37 UTC'),story.started)
    assert_equal('unknown',story.ticket_type)
  end
  
  def test_malformed_posts_fail_cleanly
    provide_stories
    Story.find_last_by_ticket_id(1).destroy
    File.open("./test/xml/create.xml") do |file|
      PtApi.incomming(file.read)
    end
    File.open("./test/xml/accepted.xml") do |file|
      PtApi.incomming(file.read)
    end
    File.open("./test/xml/start.xml") do |file|
      PtApi.incomming(file.read)
    end
    File.open("./test/xml/start2.xml") do |file|
      PtApi.incomming(file.read)
    end
    File.open("./test/xml/nonsense.xml") do |file|
      PtApi.incomming(file.read)
    end
    File.open("./test/xml/invalid.xml") do |file|
      PtApi.incomming(file.read)
    end
    assert Message.count == 0
    story = Story.find_last_by_ticket_id(1)
    assert_equal('accepted',story.state.name)
    assert_equal(Time.parse('2012/02/01 12:03:36 UTC'),story.accepted)
    assert_equal(Time.parse('2012/02/01 11:05:51 UTC'),story.started)
  end
  
  def test_changes_to_story_update_handle_edits
    story = Story.create!(:ticket_id=>1, :name=>"Replace this", :ticket_type=>'feature', :created=>Time.parse('2012/02/01 12:03:36 UTC'))
    assert_equal("Replace this",story.name)
    assert_equal('feature',story.ticket_type)
    assert_equal(Time.parse('2012/02/01 12:03:36 UTC'),story.created)
    assert_equal('created',story.state.name)
    File.open("./test/xml/update1.xml") do |file|
      PtApi.incomming(file.read)
    end
    story.reload
    assert_equal("Replace this",story.name)
    assert_equal('bug',story.ticket_type)
    assert_equal(Time.parse('2012/02/01 12:03:36 UTC'),story.created)
    assert_equal('created',story.state.name)
    File.open("./test/xml/update2.xml") do |file|
      PtApi.incomming(file.read)
    end
    story.reload
    assert_equal("With a new name",story.name)
    assert_equal('bug',story.ticket_type)
    assert_equal(Time.parse('2012/02/01 12:03:36 UTC'),story.created)
    assert_equal('created',story.state.name)
    assert Message.count == 0
  end
  
  def test_validation
    File.open("./test/xml/nonsense.xml") do |file|
      assert !PtApi::StoryXML.new(file.read).is_valid?
    end
    File.open("./test/xml/nonsense.xml") do |file|
      assert !PtApi::StoryXML.new(file.read).is_valid?
    end
    File.open("./test/xml/popbig.xml") do |file|
      assert PtApi::StoryXML.new(file.read,[1,2,3]).is_valid?
    end
  end
  
  def teardown
    Story.delete_all
  end
  
end

class MyUnitTests < Test::Unit::TestCase

  include ::TestHelpers

  def setup
    Message.each! {|m| }
  end

  def test_testing_environment
    assert(test?)
  end

  def test_stories_can_be_created_and_retrieved
    Story.create!(
    :ticket_id=>1,
    :name => 'foo',
    :created => '2012-01-31 [14:31:32]',
    :ticket_type => 'bug')
    story = Story.find_last_by_ticket_id(1)
    assert_equal(1,story.ticket_id)
    assert_equal('foo',story.name)
    assert_equal(Time.parse('2012-01-31 [14:31:32]'),story.created)
    assert_equal('bug',story.ticket_type)
  end

  def test_method_accessors_return_stories
    provide_stories
    assert_counts(0,[1,2,2,1,3,0,9,9])
  end

  def test_iteration_counts_are_correct
    story=Story.create!(
    :ticket_id=>1,
    :created => '2012-02-09 [14:31:32]')
    assert_counts(4,[1,0,0,0,0,0,0,1])

    story.started='2012-02-09 [14:31:33]'
    story.save
    assert_counts(4,[0,1,0,0,0,0,1,1])

    story.finished='2012-02-09 [14:31:34]'
    story.save
    assert_counts(4,[0,0,1,0,0,0,1,1])

    story.delivered='2012-02-09 [14:31:35]'
    story.save
    assert_counts(4,[0,0,0,1,0,0,1,1])

    story.accepted='2012-02-09 [14:31:36]'
    story.save
    assert_counts(4,[0,0,0,0,1,0,1,1])

    story.reject('2012-02-09 [14:31:37]')
    assert_counts(4,[0,0,0,0,0,1,1,1])

    story.update_state('started','2012-02-09 [14:31:38]')
    assert_counts(4,[0,1,0,0,0,0,1,2])

    story = Story.find_last_by_ticket_id(1)
    story.reject('2012-02-09 [14:31:39]')
    assert_counts(4,[0,0,0,0,0,1,1,2])

    story.update_state('started','2012-02-09 [14:31:40]')
    assert_counts(4,[0,1,0,0,0,0,1,3])

  end

  def test_iteration_counts_are_correct_2
    Story.create!(
      :ticket_id=>1,
      :created => '2012-02-09 [14:31:32]'
    )
    Story.create!(
      :ticket_id=>9,
      :created => '1266-02-09 [14:31:32]'
    )
    Story.create!(
      :ticket_id=>10,
      :created => '3266-02-09 [14:31:32]'
    )
    Story.create!(
      :ticket_id=>2,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]'
    )
    Story.create!(
      :ticket_id=>3,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]'
    )
    Story.create!(
      :ticket_id=>4,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2012-02-09 [14:31:35]'
    )
    Story.create!(
      :ticket_id=>5,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2012-02-09 [14:31:35]',
      :accepted => '2012-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>6,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2012-02-09 [14:31:35]',
      :rejected => '2012-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>7,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2012-02-09 [14:31:35]',
      :rejected => '2012-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>7,
      :started => '2012-02-09 [14:31:37]'
    )
    Story.create!(
      :ticket_id=>8,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2012-02-09 [14:31:35]',
      :rejected => '2012-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>8,
      :started => '2036-01-04 [12:23:11]'
    )
    Story.create!(
      :ticket_id=>11,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2012-02-09 [14:31:35]',
      :rejected => '2036-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>12,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2012-02-09 [14:31:35]',
      :accepted => '2036-02-09 [14:31:36]'
    )  
    Story.create!(
      :ticket_id=>13,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2012-02-09 [14:31:34]',
      :delivered => '2036-02-09 [14:31:35]',
      :accepted => '2036-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>14,
      :created => '2012-02-09 [14:31:32]',
      :started => '2012-02-09 [14:31:33]',
      :finished => '2036-02-09 [14:31:34]',
      :delivered => '2036-02-09 [14:31:35]',
      :accepted => '2036-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>15,
      :created => '2012-02-09 [14:31:32]',
      :started => '2036-02-09 [14:31:33]',
      :finished => '2036-02-09 [14:31:34]',
      :delivered => '2036-02-09 [14:31:35]',
      :accepted => '2036-02-09 [14:31:36]'
    )
    Story.create!(
      :ticket_id=>16,
      :created => '1066-02-09 [14:31:32]',
      :started => '2036-02-09 [14:31:33]',
      :finished => '2036-02-09 [14:31:34]',
      :delivered => '2036-02-09 [14:31:35]',
      :accepted => '2036-02-09 [14:31:36]'
    )
    # Totals
    assert_counts(0,[3,3,1,1,6,2,16,18])

    # Iteration
    assert_counts(4,[2,3,2,3,1,2,11,18])

  end

  def test_iteration_counts_are_correct_5
    Story.create!(
    :ticket_id=>1,
    :created => '2012-02-01 [14:31:32]',
    :rejected => '2012-02-01 [14:31:33]'
    )
    Story.create!(
    :ticket_id=>2,
    :created => '2012-02-09 [14:31:32]',
    :rejected => '2012-02-09 [14:31:33]'
    )
    Story.create!(
    :ticket_id=>3,
    :created => '2012-02-09 [14:31:32]',
    :rejected => '2013-02-09 [14:31:33]'
    )
    Story.create!(
    :ticket_id=>4,
    :created => '2012-02-01 [14:31:32]',
    :rejected => '2012-02-09 [14:31:33]'
    )
    Story.create!(
    :ticket_id=>5,
    :created => '2014-02-09 [14:31:32]',
    :rejected => '2014-02-09 [14:31:33]'
    )
    # Totals
    assert_counts(0,[0,0,0,0,0,5,5,5])

    # Iteration
    assert_counts(4,[1,0,0,0,0,3,3,5])

  end

  def test_iteration_counts_are_correct_3
    Story.create!(
    :ticket_id=>1,
    :created => '1066-02-09 [14:31:32]',
    :started => '1066-02-09 [14:31:33]',
    :finished => '1066-02-09 [14:31:34]',
    :delivered => '1066-02-09 [14:31:35]',
    :accepted => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>2,
    :created => '2036-02-09 [14:31:32]',
    :started => '2036-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>3,
    :created => '1066-02-09 [14:31:32]',
    :started => '1066-02-09 [14:31:33]',
    :finished => '1066-02-09 [14:31:34]',
    :delivered => '1066-02-09 [14:31:35]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>3,
    :started => '2036-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]')
    Story.create!(
    :ticket_id=>4,
    :created => '1066-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>5,
    :created => '1066-02-09 [14:31:32]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>5,
    :started => '2036-02-09 [14:31:33]',
    :finished=> '2036-02-09 [14:31:34]')
    Story.create!(
    :ticket_id=>6,
    :created => '1066-02-09 [14:31:32]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>6,
    :started => '1666-02-09 [14:31:33]',
    :rejected => '1667-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>6,
    :started => '2036-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>7,
    :created => '1066-02-09 [14:31:32]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7,
    :started => '1666-02-09 [14:31:33]',
    :rejected => '1667-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7,
    :started => '2012-02-09 [14:31:33]')
    # Totals
    assert_counts(0,[0,2,1,1,3,0,7,13])
    # Iteration
    assert_counts(4,[0,2,0,0,0,3,5,13])

  end

  def test_iteration_counts_are_correct_4
    Story.create!(
    :ticket_id=>1,
    :created => '1066-02-09 [14:31:32]',
    :started => '1066-02-09 [14:31:33]',
    :finished => '1066-02-09 [14:31:34]',
    :delivered => '1066-02-09 [14:31:35]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>1,
    :started => '1566-02-09 [14:31:33]',
    :finished => '1566-02-09 [14:31:34]',
    :delivered => '1566-02-09 [14:31:35]',
    :rejected => '1566-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>1,
    :started => '1666-02-09 [14:31:33]',
    :finished => '1666-02-09 [14:31:34]',
    :delivered => '1666-02-09 [14:31:35]',
    :rejected => '1666-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>1,
    :started => '1766-02-09 [14:31:33]',
    :finished => '1766-02-09 [14:31:34]',
    :delivered => '1766-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>2,
    :created => '1066-02-09 [14:31:32]',
    :started => '1066-02-09 [14:31:33]',
    :finished => '1066-02-09 [14:31:34]',
    :delivered => '1066-02-09 [14:31:35]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>2,
    :started => '1566-02-09 [14:31:33]',
    :finished => '1566-02-09 [14:31:34]',
    :delivered => '1566-02-09 [14:31:35]',
    :rejected => '1566-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>2,
    :started => '1666-02-09 [14:31:33]',
    :finished => '1666-02-09 [14:31:34]',
    :delivered => '1666-02-09 [14:31:35]',
    :rejected => '1666-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>2,
    :started => '1766-02-09 [14:31:33]',
    :finished => '1766-02-09 [14:31:34]',
    :delivered => '1766-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>2,
    :started => '2012-02-09 [14:33:33]')
    Story.create!(
    :ticket_id=>3,
    :created => '1066-02-09 [14:31:32]',
    :started => '1066-02-09 [14:31:33]',
    :finished => '1066-02-09 [14:31:34]',
    :delivered => '1066-02-09 [14:31:35]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>3,
    :started => '1566-02-09 [14:31:33]',
    :finished => '1566-02-09 [14:31:34]',
    :delivered => '1566-02-09 [14:31:35]',
    :rejected => '1566-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>3,
    :started => '1666-02-09 [14:31:33]',
    :finished => '1666-02-09 [14:31:34]',
    :delivered => '1666-02-09 [14:31:35]',
    :rejected => '1666-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>3,
    :started => '1766-02-09 [14:31:33]',
    :finished => '1766-02-09 [14:31:34]',
    :delivered => '1766-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>3,
    :started => '2032-02-09 [14:33:33]')
    # Totals
    assert_counts(0,[0,2,0,0,0,1,3,14])

    # Iteration
    assert_counts(4,[0,1,0,0,0,2,3,14])

  end

  def test_state_returns_current_state
    provide_stories
    assert_equal("created",Story.find_last_by_ticket_id(1).state.name)
    assert_equal("started",Story.find_last_by_ticket_id(2).state.name)
    assert_equal("started",Story.find_last_by_ticket_id(3).state.name)
    assert_equal("finished",Story.find_last_by_ticket_id(4).state.name)
    assert_equal("finished",Story.find_last_by_ticket_id(5).state.name)
    assert_equal("delivered",Story.find_last_by_ticket_id(6).state.name)
    assert_equal("accepted",Story.find_last_by_ticket_id(7).state.name)
    assert_equal("accepted",Story.find_last_by_ticket_id(8).state.name)
    assert_equal("accepted",Story.find_last_by_ticket_id(9).state.name)
  end

  def test_update_state_updates_state
    Story.create!(
    :ticket_id=>1,
    :name => 'foo',
    :created => '2012-01-31 [14:31:32]',
    :ticket_type => 'bug')

    assert_equal("created",Story.find_last_by_ticket_id(1).state.name)
    Story.find_last_by_ticket_id(1).update_state("started","2013/01/31 13:37:51 UTC")
    assert_equal("started",Story.find_last_by_ticket_id(1).state.name)
    assert_equal(true,Story.find_last_by_ticket_id(1).created?)
    assert_equal(true,Story.find_last_by_ticket_id(1).started?)
    assert_equal(false,Story.find_last_by_ticket_id(1).finished?)
    assert_equal(false,Story.find_last_by_ticket_id(1).delivered?)
    assert_equal(false,Story.find_last_by_ticket_id(1).accepted?)
    assert_equal(false,Story.find_last_by_ticket_id(1).rejected?)
    assert_counts(0,[0,1,0,0,0,0,1,1])

    # Check we can skip a stage (In case we miss an update)
    Story.find_last_by_ticket_id(1).update_state("delivered","2014/01/31 13:37:51 UTC")
    assert_equal("delivered",Story.find_last_by_ticket_id(1).state.name)
    assert_equal(true,Story.find_last_by_ticket_id(1).created?)
    assert_equal(true,Story.find_last_by_ticket_id(1).started?)
    assert_equal(false,Story.find_last_by_ticket_id(1).finished?)
    assert_equal(true,Story.find_last_by_ticket_id(1).delivered?)
    assert_equal(false,Story.find_last_by_ticket_id(1).accepted?)
    assert_equal(false,Story.find_last_by_ticket_id(1).rejected?)
    assert_counts(0,[0,0,0,1,0,0,1,1])
    assert_equal(1,Story.total(Iteration.all).length)

    # Check that we can't go back a stage on old events
    Story.find_last_by_ticket_id(1).update_state("finished","2014/01/31 13:37:50 UTC")
    story = Story.find_last_by_ticket_id(1)
    assert_equal("delivered",story.state.name)
    assert_equal(true,story.created?)
    assert_equal(true,story.started?)
    assert_equal(true,story.finished?)
    assert_equal(true,story.delivered?)
    assert_equal(false,story.accepted?)
    assert_equal(false,story.rejected?)
    assert_equal(Time.parse("2014/01/31 13:37:50 UTC"),story.finished)
    assert_counts(0,[0,0,0,1,0,0,1,1])

    # Check that we do go back a stage on NEW events
    Story.find_last_by_ticket_id(1).update_state("finished","2014/01/31 13:37:51 UTC")
    story = Story.find_last_by_ticket_id(1)
    assert_equal("finished",story.state.name)
    assert_equal(false,story.created?)
    assert_equal(false,story.started?)
    assert_equal(true,story.finished?)
    assert_equal(false,story.delivered?)
    assert_equal(false,story.accepted?)
    assert_equal(false,story.rejected?)
    assert_equal(Time.parse("2014/01/31 13:37:51 UTC"),story.finished)
    assert_counts(0,[0,0,1,0,0,0,1,2])

  end

  def test_starting_rejected_stories_provides_new_story
    provide_stories
    assert_equal(0,Story.find_last_by_ticket_id(6).rejection_count)
    Story.find_last_by_ticket_id(6).reject("2014/01/31 13:37:51 UTC")
    assert_equal("rejected",Story.find_last_by_ticket_id(6).state.name)
    Story.find_last_by_ticket_id(6).update_state('started','2014/06/03')
    assert_equal(2,Story.find_all_by_ticket_id(6).length)
    story = Story.find_last_by_ticket_id(6)
    assert_equal("started",story.state.name)
    assert_equal(false,story.created?)
    assert_equal(true,story.started?)
    assert_equal(false,story.finished?)
    assert_equal(false,story.delivered?)
    assert_equal(false,story.accepted?)
    assert_equal(1,story.rejection_count)
    #assert Story.where("rejected IS NOT NULL").first.finished?
    story.reject("2015/01/31 13:37:51 UTC")
    story.update_state('started','2062/01/03')
    story.reload
    assert_equal(3,Story.find_all_by_ticket_id(6).length)
    assert_equal(2,story.rejection_count)
  end

  def test_delayed_tickets_on_rejected_stories
    original = Story.create(
    :ticket_id=>1,
    :name => 'foo',
    :created => '1983-01-31 [14:31:32]',
    :ticket_type => 'bug')
    original.update_state("started","01/01/2000")
    original.reject("01/12/2000")
    second = Story.find_last_by_ticket_id(1)
    second.update_state("finished","01/06/2000")
    original.reload
    second.reload
    assert_equal(true,original.rejected?)
    assert_equal(true,original.finished?)
    assert_equal(true,second.finished?)
    assert_equal(true,second.started?)
  end

  def test_api_calls
    return nil if $NO_API
    assert $SETTINGS["api_token"]
    resource_uri = URI.parse("http://www.pivotaltracker.com/services/v3/projects/#{$SETTINGS["project_id"]}/stories?filter=id:#{$SETTINGS["test_ticket_id"]}")
    event = PtApi::Request.new($SETTINGS["project_id"],$SETTINGS["api_token"],'all').fetch(resource_uri)
    assert event.is_valid?
  end
  
  def test_bad_api_calls
    return nil if $NO_API
    resource_uri = URI.parse("http://www.pivotaltracker.com/services/v3/projects/#{$SETTINGS["project_id"]}/stories/#{$SETTINGS["test_ticket_id"]}")
    event = PtApi::Request.new($SETTINGS["project_id"],'invalid','all').fetch(resource_uri)
    assert event.is_valid? == false
    assert Message.count==1
  end

  def test_populate_functions_work
    return nil if $NO_API
    assert Story.count == 0
    assert $SETTINGS['api_token'] != nil
    PtApi::PopulateDb.new($SETTINGS['project_id'],$SETTINGS['api_token'],'all').do
    assert Story.count > 0
    story = Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"])
    assert_equal($SETTINGS["test_ticket_name"],story.name)
    assert story.created?
  end

  def test_incomplete_tickets_returns_incomplete_tickets
    ['1','2','3','6','9'].each do |ticket_id|
      Story.create!( # Create story with placeholders
      :ticket_id => ticket_id,
      :name => "Unknown story",
      :created => nil,
      :ticket_type => 'unknown'
      )
    end
    ['4','5','7','8'].each do |ticket_id|
      Story.create!( # Create story with placeholders
      :ticket_id => ticket_id,
      :name => "Valid story",
      :created => Time.parse('01/01/2001'),
      :ticket_type => 'bug'
      )
    end
    incomplete = Story.incomplete
    assert incomplete.length == 5
    assert incomplete.include?(1)
    assert incomplete.include?(6)
    assert !incomplete.include?(4)
    assert !incomplete.include?(8)
  end

  def test_no_created_nolonger_incomplete
    Story.create!( # Create story with placeholders
    :ticket_id => 1,
    :name => "Known story",
    :created => nil,
    :ticket_type => 'bug'
    )
    assert_equal(0,Story.incomplete.length)
  end

  def test_clones_date_not_updated
    Story.create!(
    :ticket_id => $SETTINGS["test_ticket_id"],
    :name => 'Unknown story',
    :created => Time.parse('01-01-2000'),
    :started => Time.parse('01-02-2000'),
    :finished => Time.parse('01-03-2000')
    )
    story = Story.create!(
    :ticket_id => $SETTINGS["test_ticket_id"],
    :name => 'Unknown story',
    :started => Time.parse('01-04-2000')
    )
    assert_equal(2,Story.incomplete.length)
    return nil if $NO_API
    PtApi::PopulateDb.new($SETTINGS['project_id'],$SETTINGS['api_token'],'all').do
    story.reload
    assert_equal($SETTINGS['test_ticket_name'], story.name)
    assert story.ori_created != nil
    assert story.created.nil?
  end

  def test_original_is_updated
    Story.create!(
    :ticket_id => $SETTINGS["test_ticket_id"],
    :name => $SETTINGS['test_ticket_name'],
    :started => Time.parse('01-02-2000'),
    :finished => Time.parse('01-03-2000')
    )
    story = Story.create!(
    :ticket_id => $SETTINGS["test_ticket_id"],
    :name => $SETTINGS['test_ticket_name'],
    :started => Time.parse('01-04-2000')
    )
    assert Story.incomplete.empty?
    return nil if $NO_API
    PtApi::PopulateDb.new($SETTINGS['project_id'],$SETTINGS['api_token'],'all').do
    story.reload
    assert_equal($SETTINGS['test_ticket_name'], story.name)
    assert story.ori_created != nil
    assert story.created.nil?
  end

  def test_stories_can_be_deleted
    provide_stories
    story = Story.find_last_by_ticket_id(3)
    story.delete('2007-08-01') # Delete a story
    story.reload
    assert_equal(true, story.deleted?)
    assert_equal('deleted',story.state.name) 
    assert_equal(8,Story.total(Iteration.all).length) # It doesn't count
    assert_equal(9,Story.count) # But it is not gone forever
    assert_equal(1,Story.started(Iteration.all).length)
  end

  def test_delete_deletes_all_tickets_with_same_id
    Story.create!(
    :ticket_id=>1,
    :created => '1066-02-09 [14:31:32]',
    :started => '1066-02-09 [14:31:33]',
    :finished => '1066-02-09 [14:31:34]',
    :delivered => '1066-02-09 [14:31:35]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>1,
    :created => '1066-02-09 [14:31:32]',
    :started => '1566-02-09 [14:31:33]',
    :finished => '1566-02-09 [14:31:34]',
    :delivered => '1566-02-09 [14:31:35]',
    :rejected => '1566-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>1,
    :created => '1066-02-09 [14:31:32]',
    :started => '1666-02-09 [14:31:33]',
    :finished => '1666-02-09 [14:31:34]',
    :delivered => '1666-02-09 [14:31:35]',
    :rejected => '1666-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>1,
    :created => '1066-02-09 [14:31:32]',
    :started => '1766-02-09 [14:31:33]',
    :finished => '1766-02-09 [14:31:34]',
    :delivered => '1766-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:33]')
    Story.find_last_by_ticket_id(1).delete('2012-02-09 [14:31:33]')
    assert_equal(0,Story.total(Iteration.all).length)
    Story.find_all_by_ticket_id(1).each do |s|
      assert s.deleted?
    end
  end

  def test_scan_for_all_deleted_stories
    return nil if $NO_API
    provide_stories
    Story.create!(:ticket_id=>$SETTINGS["test_ticket_id"])
    PtApi::FlagDeleted.new($SETTINGS['project_id'],$SETTINGS['api_token'],'all').do
    assert Story.find_last_by_ticket_id(2).deleted?
    assert Story.find_last_by_ticket_id(4).deleted?
    assert Story.find_last_by_ticket_id(9).deleted?
    assert !Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"]).deleted?
  end

  def test_scan_for_specific_deleted_stories
    return nil if $NO_API
    provide_stories
    Story.create(:ticket_id=>$SETTINGS["test_ticket_id"])
    PtApi::FlagDeleted.new($SETTINGS['project_id'],$SETTINGS['api_token'],[2,4,$SETTINGS["test_ticket_id"]]).do
    assert Story.find_last_by_ticket_id(2).deleted?
    assert Story.find_last_by_ticket_id(4).deleted?
    assert !Story.find_last_by_ticket_id(9).deleted?
    assert !Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"]).deleted?
  end

  def test_ticket_type_counts_are_correct
    #Basic tests
    provide_stories
    assert_equal(7,Story.bugs(Iteration.all).length)
    assert_equal(1,Story.features(Iteration.all).length)
    assert_equal(1,Story.chores(Iteration.all).length)
    assert_equal(0,Story.releases(Iteration.all).length)
    Story.destroy_all
    #Iteration counts
    Story.create!(
    :ticket_id=>1, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]'
    )
    Story.create!(
    :ticket_id=>2, :ticket_type=> 'feature',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]'
    )
    Story.create!(
    :ticket_id=>3, :ticket_type=> 'chore',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]'
    )
    Story.create!(
    :ticket_id=>4, :ticket_type=> 'release',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :accepted => '2012-02-09 [14:31:36]'
    )
    assert_equal(1,Story.bugs(Iteration.all).length)
    assert_equal(1,Story.features(Iteration.all).length)
    assert_equal(1,Story.chores(Iteration.all).length)
    assert_equal(1,Story.releases(Iteration.all).length)
    assert_equal(1,Story.bugs(4.iteration).length)
    assert_equal(1,Story.features(4.iteration).length)
    assert_equal(1,Story.chores(4.iteration).length)
    assert_equal(1,Story.releases(4.iteration).length)
    assert_equal(0,Story.bugs(3.iteration).length)
    assert_equal(0,Story.features(3.iteration).length)
    assert_equal(0,Story.chores(3.iteration).length)
    assert_equal(0,Story.releases(3.iteration).length)
    #More complicated
    Story.destroy_all
    Story.create!(
    :ticket_id=>1, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]')
    Story.create!(
    :ticket_id=>9, :ticket_type => 'bug',
    :created => '1266-02-09 [14:31:32]')
    Story.create!(
    :ticket_id=>10, :ticket_type => 'bug',
    :created => '3266-02-09 [14:31:32]')
    Story.create!(
    :ticket_id=>2, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>3, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]')
    Story.create!(
    :ticket_id=>4, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]'
    )
    Story.create!(
    :ticket_id=>5, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :accepted => '2012-02-09 [14:31:36]'
    )
    Story.create!(
    :ticket_id=>6, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7, :ticket_type => 'bug',
    :started => '2012-02-09 [14:31:37]')
    Story.create!(
    :ticket_id=>8, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>8, :ticket_type => 'bug',
    :started => '2036-01-04 [12:23:11]')
    Story.create!(
    :ticket_id=>11, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :rejected => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>12, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')  
    Story.create!(
    :ticket_id=>13, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>14, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>15, :ticket_type => 'bug',
    :created => '2012-02-09 [14:31:32]',
    :started => '2036-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>16, :ticket_type => 'bug',
    :created => '1066-02-09 [14:31:32]',
    :started => '2036-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    # Totals
    assert_equal(16,Story.bugs(Iteration.all).length,  "With: #{Story.bugs(Iteration.all).inspect}")
    # Iteration
    assert_equal(11,Story.bugs(4.iteration).length,  "With: #{Story.bugs(4.iteration).inspect}")
  end

  def test_iteration_counts_on_edited_tickets

    a = Story.create!(
    :ticket_id=>1,
    :created => current_iteration(0))

    a.update_state('started', current_iteration(1) )

    a.reload
    assert_equal('started',a.state.name)
    assert_counts(0,[0,1,0,0,0,0,1,1])
    assert_counts(4,[0,1,0,0,0,0,1,1])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('started', current_iteration(1) )

    b.reload
    assert_equal('started',b.state.name)
    assert_counts(0,[0,1,0,0,0,0,1,1])
    assert_counts(4,[0,1,0,0,0,0,1,1])
    assert_counts(3,[1,0,0,0,0,0,0,1])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('started', current_iteration(1) )
    b.update_state('started', current_iteration(1) )

    b.reload
    assert_equal('started',b.state.name)
    assert_counts(0,[0,1,0,0,0,0,1,1])
    assert_counts(4,[0,1,0,0,0,0,1,1])
    assert_counts(3,[1,0,0,0,0,0,0,1])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('started', previous_iteration(1) )
    b.update_state('finished', previous_iteration(2) )
    b.update_state('started', current_iteration(1) )

    b.reload
    assert_equal('finished',b.state.name)
    assert_counts(0,[0,1,0,0,0,0,1,2])
    assert_counts(4,[0,1,0,0,0,0,1,2])
    assert_counts(3,[0,0,1,0,0,0,1,2])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('started', previous_iteration(1) )
    b.update_state('finished', previous_iteration(2) )
    b.update_state('started', subsequent_iteration(1) )

    b.reload
    assert_equal('finished',b.state.name)
    assert_counts(0,[0,1,0,0,0,0,1,2])
    assert_counts(4,[0,0,1,0,0,0,1,2])
    assert_counts(3,[0,0,1,0,0,0,1,2])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('started', previous_iteration(1) )
    b.update_state('finished', previous_iteration(2) )
    b.update_state('delivered', previous_iteration(2) )
    b.update_state('finished', subsequent_iteration(1) )

    b.reload
    assert_equal('delivered',b.state.name)
    assert_counts(0,[0,0,1,0,0,0,1,2])
    assert_counts(4,[0,0,0,1,0,0,1,2])
    assert_counts(3,[0,0,0,1,0,0,1,2]) # Error here

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('started', previous_iteration(1) )
    b.update_state('finished', previous_iteration(2) )
    b.update_state('delivered', previous_iteration(3) )
    b.update_state('accepted', previous_iteration(4) )
    b.update_state('delivered', current_iteration(1) )

    b.reload
    assert_equal('accepted',b.state.name)
    assert_counts(0,[0,0,0,1,0,0,1,2])
    assert_counts(4,[0,0,0,1,0,0,1,2])
    assert_counts(3,[0,0,0,0,1,0,1,2])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('accepted', previous_iteration(1) )
    b.update_state('started', previous_iteration(2) )

    b.reload
    assert_equal('accepted',b.state.name)
    assert_counts(0,[0,1,0,0,0,0,1,2])
    assert_counts(4,[0,1,0,0,0,0,1,2])
    assert_counts(3,[0,1,0,0,0,0,1,2])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('accepted', previous_iteration(1) )
    b.update_state('started', current_iteration(2) )

    b.reload
    assert_equal('accepted',b.state.name)
    assert_counts(0,[0,1,0,0,0,0,1,2])
    assert_counts(4,[0,1,0,0,0,0,1,2])
    assert_counts(3,[0,0,0,0,1,0,1,2])

    Story.destroy_all

    b = Story.create!(
    :ticket_id=>2,
    :created => previous_iteration(0))

    b.update_state('started', previous_iteration(1) )
    b.update_state('finished', previous_iteration(2) )
    b.update_state('delivered', previous_iteration(3) )
    b.update_state('accepted', previous_iteration(4) )
    b.update_state('finished', current_iteration(1) )

    b.reload
    assert_equal('accepted',b.state.name)
    assert_counts(0,[0,0,1,0,0,0,1,2])
    assert_counts(4,[0,0,1,0,0,0,1,2])
    assert_counts(3,[0,0,0,0,1,0,1,2])

    Story.destroy_all

  end

  def test_unstarting_stories_works
    story = Story.create!(
    :ticket_id => 1,
    :created => current_iteration(0),
    :started => current_iteration(1))
    story.update_state('unstarted',current_iteration(2))

    assert_counts(0,[1,0,0,0,0,0,1,2])
    assert_counts(4,[1,0,0,0,0,0,0,2])
    story = Story.find_last_by_ticket_id(1)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse(current_iteration(0)),story.ori_created)
    assert_equal(Time.parse(current_iteration(2)),story.created)

    Story.destroy_all

    story = Story.create!(
    :ticket_id => 1,
    :created => current_iteration(0),
    :started => current_iteration(1))
    story.update_state('unscheduled',current_iteration(2))

    assert_counts(0,[1,0,0,0,0,0,1,2])
    assert_counts(4,[1,0,0,0,0,0,0,2])
    story = Story.find_last_by_ticket_id(1)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse(current_iteration(0)),story.ori_created)
    assert_equal(Time.parse(current_iteration(2)),story.created)

    Story.destroy_all

    # And things don't happen for equal or pre-dates
    story = Story.create!(
    :ticket_id => 1,
    :created => current_iteration(0),
    :started => current_iteration(1))
    story.update_state('unstarted',current_iteration(0))
    story = Story.create!(
    :ticket_id => 2,
    :created => current_iteration(1),
    :started => current_iteration(2))
    story.update_state('unstarted',current_iteration(0))

    assert_counts(0,[0,2,0,0,0,0,2,2])
    assert_counts(4,[0,2,0,0,0,0,2,2])
    story = Story.find_last_by_ticket_id(1)
    assert_equal('started',story.state.name)
    assert_equal(Time.parse(current_iteration(0)),story.ori_created)
    assert_equal(Time.parse(current_iteration(0)),story.created)
    story = Story.find_last_by_ticket_id(2)
    assert_equal('started',story.state.name)
    assert_equal(current_iteration(1).to_time, story.ori_created)
    assert_equal(current_iteration(1).to_time, story.created)

    Story.destroy_all

    # And things work across iterations

    story = Story.create!(
    :ticket_id => 1,
    :created => current_iteration(0),
    :started => current_iteration(1))
    story.update_state('unstarted',subsequent_iteration(2))

    assert_counts(0,[1,0,0,0,0,0,1,2])
    assert_counts(4,[0,1,0,0,0,0,1,2])
    assert_counts(5,[1,0,0,0,0,0,0,2])
    story = Story.find_last_by_ticket_id(1)
    assert_equal('created',story.state.name)
    assert_equal(Time.parse(current_iteration(0)),story.ori_created)
    assert_equal(Time.parse(subsequent_iteration(2)),story.created)

    Story.destroy_all

  end

  def test_errors_in_counts_with_complex_data

    Story.create!( :id => 18, :ticket_id => 24692539, :name => "Testing Created Count Without Rejection", :created => "2012-02-09 10:51:31", 
    :started => "2012-02-09 10:51:31", :finished=> "2012-02-15 16:11:43", :delivered=> "2012-02-15 16:11:44", :accepted=> nil, :rejected=> "2012-02-15 16:14:55", :deleted=> nil, :ticket_type=> "feature")
    Story.create!( :id => 30, :ticket_id => 24692539, :name => "Testing Created Count Without Rejection", :created => nil,
    :started => "2012-02-16 11:19:10", :finished=> "2012-02-17 10:23:47", :delivered=> "2012-02-17 10:25:31", :accepted=> nil, :rejected=> "2012-02-17 10:26:05", :deleted=> nil, :ticket_type=> "feature")
    Story.create!( :id => 25, :ticket_id => 24692539, :name => "Testing Created Count Without Rejection", :created => "2012-02-09 10:51:31",
    :started => "2012-02-15 16:15:12", :finished=> "2012-02-16 11:18:49", :delivered=> "2012-02-16 11:18:50", :accepted=> nil, :rejected=> "2012-02-16 11:18:51", :deleted=> nil, :ticket_type=> "feature")
    Story.create!( :id => 42, :ticket_id => 24692539, :name => "Testing Created Count Without Rejection", :created => nil,
    :started => "2012-02-17 10:27:55", :finished=> nil, :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "feature")
    Story.create!( :id => 48, :ticket_id => 24692539, :name => "Testing Created Count Without Rejection", :created => "2012-02-17 11:16:36",
    :started => nil, :finished=> nil, :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "feature")

    assert_counts(0,[1,0,0,0,0,0,1,5])

    Story.create!( :id => 53, :ticket_id => 24692539, :name => "Testing Created Count Without Rejection", :created => nil,
    :started => "2012-02-17 11:38:41", :finished=> nil, :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "feature")

    assert_counts(0,[0,1,0,0,0,0,1,6])
    assert_counts(5,[0,1,0,0,0,0,1,6])

  end

  def test_poprepair_updates_states
    Story.create!( :id => 1, :ticket_id => 1, :name => "A", :created => "2012-02-17 10:32:07", :started=> nil,
    :finished=> nil, :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "chore")
    Story.create!( :id => 2, :ticket_id => 2, :name => "B", :created => "2012-02-17 10:32:07", :started=> "2012-02-17 10:32:37",
    :finished=> nil, :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "chore")
    Story.create!( :id => 3, :ticket_id => 3, :name => "C", :created => "2012-02-17 10:32:07", :started=> "2012-02-17 10:32:37",
    :finished=> "2012-02-17 10:40:37", :delivered=> nil, :accepted=> nil, :rejected=> nil, :deleted=> nil, :ticket_type=> "chore")

    PtApi::StoryXML.read_file("./test/xml/popbig.xml").parse(0)

    assert_equal('started',Story.find_last_by_ticket_id(1).state.name)
    assert_equal('started',Story.find_last_by_ticket_id(2).state.name)
    assert_equal('started',Story.find_last_by_ticket_id(3).state.name)

    assert_counts(0,[0,3,0,0,0,0,3,4])
    assert_counts(5,[0,3,0,0,0,0,3,4])
    assert_counts(5,[0,3,0,0,0,0,3,4])

    assert_equal(Time.parse('2012/02/17 10:32:07 UTC'),Story.find_last_by_ticket_id(1).started)
    assert_equal(Time.parse("2012-02-17 10:32:37"),Story.find_last_by_ticket_id(2).started)
    assert_equal(Time.parse("2012-02-17 10:40:37"),Story.find_last_by_ticket_id(3).started)

  end

  def test_rejection_counts
    Story.create!(
    :ticket_id=>1, :ticket_type=> 'feature',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :rejected => '2012-02-09 [14:31:34]'
    )
    Story.create!(
    :ticket_id=>2, :ticket_type=> 'feature',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :rejected => '2012-02-09 [14:31:34]'
    )
    Story.create!(
    :ticket_id=>2, :ticket_type=> 'feature',
    :started => '2012-02-09 [14:32:33]',
    :rejected => '2012-02-09 [14:32:34]'
    )
    Story.create!(
    :ticket_id=>2, :ticket_type=> 'feature',
    :started => '2012-02-09 [14:33:33]',
    )
    Story.create!(
    :ticket_id=>3, :ticket_type=> 'feature',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]'
    )
    Story.create!(
    :ticket_id=>4, :ticket_type=> 'feature',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]'
    )
    Story.create!(
    :ticket_id=>4, :ticket_type=> 'feature',
    :started => '2012-02-09 [14:31:35]',
    )
    Story.create!(
    :ticket_id=>5, :ticket_type=> 'feature',
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :rejected => '2012-02-09 [14:31:34]'
    )
    Story.create!(
    :ticket_id=>5, :ticket_type=> 'feature',
    :started => '2012-02-09 [14:32:33]',
    :finished => '2012-02-09 [14:32:34]'
    )
    Story.create!(
    :ticket_id=>5, :ticket_type=> 'feature',
    :started => '2012-02-09 [14:33:33]',
    )
    assert_equal(1,Story.find_last_by_ticket_id(1).rejection_count)
    assert_equal(2,Story.find_last_by_ticket_id(2).rejection_count)
    assert_equal(0,Story.find_last_by_ticket_id(3).rejection_count)
    assert_equal(0,Story.find_last_by_ticket_id(4).rejection_count)
    assert_equal(1,Story.find_last_by_ticket_id(5).rejection_count)
  end

  def teardown
    Story.delete_all
  end
  
  def test_iterative_getters
    a = Story.create!(
    :ticket_id=>1, :ticket_type=> 'feature',
    :created => current_iteration(0),
    :started => current_iteration(1),
    :finished => current_iteration(2),
    :delivered => current_iteration(3),
    :rejected => current_iteration(4)
    )
    b = Story.create!(
    :ticket_id=>1, :ticket_type=> 'feature',
    :started => current_iteration(5),
    )
    c = Story.create!(
    :ticket_id=>2, :ticket_type=> 'feature',
    :created => current_iteration(0),
    :started => current_iteration(1),
    :finished => current_iteration(2),
    :delivered => current_iteration(3)
    )
    d = Story.create!(
    :ticket_id=>2, :ticket_type=> 'feature',
    :finished => current_iteration(4),
    :delivered => current_iteration(5)
    )
    e = Story.create!(
    :ticket_id=>3, :ticket_type=> 'feature',
    :created => current_iteration(0),
    :started => current_iteration(1),
    :finished => current_iteration(2),
    :delivered => current_iteration(3)
    )
    f = Story.create!(
    :ticket_id=>3, :ticket_type=> 'feature',
    :started => current_iteration(4),
    :finished => current_iteration(5),
    :delivered => current_iteration(6)
    )
    h = Story.create!(
    :ticket_id=>3, :ticket_type=> 'feature',
    :started => current_iteration(7),
    :finished => current_iteration(8),
    :deleted => current_iteration(9)
    )
    g = Story.create!(
    :ticket_id=>3, :ticket_type=> 'feature',
    :finished => current_iteration(10),
    :delivered => current_iteration(11)
    )
    
    assert_equal(2,a.find_ticket_stack.length)
    assert_equal(2,b.find_ticket_stack.length)
    assert_equal(2,c.find_ticket_stack.length)
    assert_equal(2,d.find_ticket_stack.length)
    assert_equal(2,a.find_ticket_stack.length)
    assert_equal(a.find_ticket_stack,b.find_ticket_stack)
    assert a.find_ticket_stack.include? a
    assert a.find_ticket_stack.include? b
    
    assert_equal(Time.parse(current_iteration(5)),b.started(true))
    assert_equal(Time.parse(current_iteration(5)),b.started(false))
    assert_equal(Time.parse(current_iteration(0)),b.created(true))
    assert_equal(nil,b.created(false))
    assert_equal(nil,b.finished(true))
    assert_equal(nil,b.finished(false))

    assert_equal(Time.parse(current_iteration(0)),d.created(true))
    assert_equal(nil, d.created(false))
    assert_equal(Time.parse(current_iteration(1)),d.started(true))
    assert_equal(nil,d.started(false))
    assert_equal(Time.parse(current_iteration(4)),d.finished(true))
    assert_equal(Time.parse(current_iteration(4)),d.finished(false))
    
    assert_equal(Time.parse(current_iteration(0)),g.created(true))
    assert_equal(nil,g.created(false))
    assert_equal(Time.parse(current_iteration(4)),g.started(true))
    assert_equal(nil,g.started(false))
    assert_equal(Time.parse(current_iteration(10)),g.finished(true))
    assert_equal(Time.parse(current_iteration(10)),g.finished(false))

  end
  
  def test_iteration_selectors
    
    assert_equal(1, 1.iteration.number)
    assert_equal(Iteration::SEED, 1.iteration.start)
    
    assert_equal(1, Iteration::SEED.iteration.number)
    assert_equal(1, (Iteration::SEED+2).iteration.number)
    
    assert_equal(4,current_iteration(0).to_time.iteration.number)
    assert_equal('2012-01-23 00:00:00 UTC'.to_time, 2.iteration.start)
    
  end
  
end

class ProblemTickets < Test::Unit::TestCase

  include ::TestHelpers

  def setup

  end

  def test_problem_ticket_counts
    t1 = Story.create!( # Good
      :ticket_id =>1, :created => current_iteration(1), :started => current_iteration(2)
    )
    t2 = Story.create!( # Good, created previous
      :ticket_id =>2, :created => previous_iteration(1), :started => current_iteration(2)
    )
    t3 = Story.create!( # Good, created previous, stalled
      :ticket_id =>3, :created => previous_iteration(1)
    )
    t4 = Story.create!( # Bad, started previous, stalled
      :ticket_id =>4, :created => previous_iteration(1), :started => previous_iteration(2)
    )
    t5 = Story.create!( # Bad, started previous, moving
      :name => 'Ticket 5', :ticket_id =>5, :created => previous_iteration(1), :started => previous_iteration(2), :finished => current_iteration(0)
    )
    t6 = Story.create!( # Bad, started more than one iteration previously, stalled
      :ticket_id =>6, :created => very_old_iteration(1), :started => very_old_iteration(2)
    )
    t7 = Story.create!( # Bad, started more than one iteration previously, moving
      :ticket_id =>7, :created => very_old_iteration(1), :started => very_old_iteration(2), :finished => current_iteration(0)
    )
    t8a = Story.create!( # Good, rejected once
      :ticket_id =>8, :created => current_iteration(1), :started => current_iteration(2), :finished => current_iteration(3),
      :delivered => current_iteration(4), :rejected => current_iteration(5)
    )
    t8b = Story.create!( # ...
      :ticket_id =>8, :started => current_iteration(6)
    )
    t9a = Story.create!( # Bad, rejected multiple times
      :ticket_id =>9, :created => current_iteration(1), :started => current_iteration(2), :finished => current_iteration(3),
      :delivered => current_iteration(4), :rejected => current_iteration(5)
    )
    t9b = Story.create!( # ...
      :ticket_id =>9, :started => current_iteration(6), :finished => current_iteration(7),
      :delivered => current_iteration(8), :rejected => current_iteration(9)
    )
    t9c = Story.create!( # ...
      :ticket_id =>9, :started => current_iteration(10)
    )
    t10a = Story.create!( # Bad, rejected multiple times AND stalled Should only count once
      :ticket_id =>10, :name => 'Test', :created => previous_iteration(1), :started => previous_iteration(2), :finished => previous_iteration(3),
      :delivered => previous_iteration(4), :rejected => previous_iteration(5)
    )
    t10b = Story.create!( # ...
      :ticket_id =>10, :name => 'Test', :started => previous_iteration(6), :finished => previous_iteration(7),
      :delivered => previous_iteration(8), :rejected => previous_iteration(9)
    )
    t10c = Story.create!( # ...
      :ticket_id =>10, :name => 'Test', :started => previous_iteration(1000)
    )
    t11 = Story.create!( # Good, accepted current, created old
      :ticket_id =>11, :created => previous_iteration(1), :started => previous_iteration(2), :finished => previous_iteration(3),
      :delivered => previous_iteration(4), :accepted => current_iteration(1)
    )
    t12 = Story.create!( # Good, accepted old, created old
      :ticket_id =>12, :created => previous_iteration(1), :started => previous_iteration(2), :finished => previous_iteration(3),
      :delivered => previous_iteration(4), :accepted => previous_iteration(5)
    )
    t13a = Story.create!( # Good, rejected multiple times, but now accepted
      :ticket_id =>13, :name => 'Test', :created => previous_iteration(1), :started => previous_iteration(2), :finished => previous_iteration(3),
      :delivered => previous_iteration(4), :rejected => previous_iteration(5)
    )
    t13b = Story.create!( # ...
      :ticket_id =>13, :name => 'Test', :started => previous_iteration(6), :finished => previous_iteration(7),
      :delivered => previous_iteration(8), :rejected => previous_iteration(9)
    )
    t13c = Story.create!( # ...
      :ticket_id =>13, :name => 'Test', :started => previous_iteration(1000), :accepted => current_iteration(1)
    )
    problem_tickets = Story.problem_tickets(4.iteration)
    assert_equal(6,problem_tickets.length)
    assert problem_tickets.include? t4
    assert problem_tickets.include? t5
    assert problem_tickets.include? t6
    assert problem_tickets.include? t7
    assert problem_tickets.include? t9c
    assert problem_tickets.include? t10c
    
    ticket = render_ticket(t10c)
    expected = <<-TICKET
<div class='ticket' id='ticket_10'>
  <h3 class='ticket_name'><a href="https://www.pivotaltracker.com/story/show/10">Test</a></h3>
  <div class='ticket_details'><span class='ticket_state'>Started</span>
  <span class='ticket_id'>10</span>
  <span class='ticket_created'>Created: 01 February 2012 14:31</span>
  <span class='ticket_started'>Started: 01 February 2012 14:48</span>
  <div class='ticket_reject_count been_rejected'><span class='ticket_reject_count_label'>Rejected</span>
    <span class='ticket_reject_count_counter'>2</span>
    <span class='ticket_reject_count_label'>times</span>
  </div></div>
</div>
TICKET
    assert ticket.gsub(/\s+/, ' ') == expected.gsub(/\s+/,' '), "Exp: #{expected.gsub(/\s+/, ' ')},
Saw: #{ticket.gsub(/\s+/, ' ')}"

    ticket = render_ticket(t5)
    expected = <<-TICKET
<div class='ticket' id='ticket_5'>
  <h3 class='ticket_name'><a href="https://www.pivotaltracker.com/story/show/5">Ticket 5</a></h3>
  <div class='ticket_details'><span class='ticket_state'>Finished</span>
  <span class='ticket_id'>5</span>
  <span class='ticket_created'>Created: 01 February 2012 14:31</span>
  <span class='ticket_started'>Started: 01 February 2012 14:31</span>
  <span class='ticket_last_action'>Finished: 09 February 2012 14:31</span>
  <div class='ticket_reject_count not_rejected'><span class='ticket_reject_count_label'>Rejected</span>
    <span class='ticket_reject_count_counter'>0</span>
    <span class='ticket_reject_count_label'>times</span>
  </div></div>
</div>
TICKET
    
    assert ticket.gsub(/\s+/, ' ') == expected.gsub(/\s+/,' '), "Exp: #{expected.gsub(/\s+/, ' ')},
Saw: #{ticket.gsub(/\s+/, ' ')}"
  end
  
  def test_last_action
    assert_equal(Time.parse(current_iteration(1)),Story.create!(
      :ticket_id =>1, :created => current_iteration(1)
      ).last_action)
    assert_equal(Time.parse(current_iteration(2)),Story.create!(
      :ticket_id =>2, :created => current_iteration(1), :started => current_iteration(2)
      ).last_action)
    assert_equal(Time.parse(current_iteration(3)),Story.create!(
      :ticket_id =>3, :created => current_iteration(1), :started => current_iteration(2), :finished => current_iteration(3)
      ).last_action)
    assert_equal(Time.parse(current_iteration(4)),Story.create!(
      :ticket_id =>4, :started => current_iteration(2), :finished => current_iteration(3), :delivered => current_iteration(4)
      ).last_action)
    assert_equal(Time.parse(current_iteration(4)),Story.create!(
      :ticket_id =>5, :created => current_iteration(1), :started => current_iteration(2), :accepted => current_iteration(4)
      ).last_action)
    assert_equal(Time.parse(current_iteration(6)),Story.create!(
      :ticket_id =>6, :created => current_iteration(1), :started => current_iteration(2), :accepted => current_iteration(5), :rejected => current_iteration(6)
      ).last_action)
  end

  def teardown
    Story.delete_all
  end

end