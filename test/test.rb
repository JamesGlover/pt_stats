ENV['RACK_ENV'] = 'test'

if ARGV.include?('--clear')
  $CLEAR = true
end


require 'rubygems'
require_relative '../web'
require 'test/unit'
require 'rack/test'

class MyUnitTests < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup
    (1..9).each do |i|
      if Story.find_by_ticket_id(i)
        if $CLEAR
          Story.find_by_ticket_id(i).destroy()
        else
          puts "WARNING! Database already populated with test entry"
          puts "Use -- --clear to automatically remove tickets"
          puts "Terminating"
          Process::exit
        end
      end
    end
  end
  
  def test_testing_environment()
    assert(test?)
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

  
  def test_our_server_works()
    authorize 'admin', 'admin'
    get '/'
    assert last_response.ok?
  end
  
  def test_return_includes_template()
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
  
  def test_page_title_is_project()
    authorize 'admin', 'admin'
    get '/'
    assert last_response.ok?
    assert last_response.body.include?($SETTINGS["project_name"])
  end
  
  def test_post_requests_do_not_return_template()
    post '/'
    assert_equal '', last_response.body
  end
  
  def test_tickets_must_have_unique_ticket_id()
    assert_raise(ActiveRecord::RecordInvalid) do
      Story.create!(:name=>'foo')
    end
    Story.create!(:ticket_id=>1)
    assert_raise(ActiveRecord::RecordInvalid) do
      Story.create!(:ticket_id=>1)
    end
  end
  
  def test_stories_can_be_created_and_retrieved()
    Story.create!(
    :ticket_id=>1,
    :name => 'foo',
    :created => '2012-01-31 [14:31:32]',
    :ticket_type => 'bug')
    story = Story.find_by_ticket_id(1)
    assert_equal(1,story.ticket_id)
    assert_equal('foo',story.name)
    assert_equal(DateTime.parse('2012-01-31 [14:31:32]'),story.created)
    assert_equal('bug',story.ticket_type)
  end
  
  def test_method_accessors_return_stories()
    provide_stories()
    assert_equal(1,Story.created.length)
    assert_equal(2,Story.started.length)
    assert_equal(2,Story.finished.length)
    assert_equal(1,Story.delivered.length)
    assert_equal(3,Story.accepted.length)
    assert_equal(9,Story.total.length)
  end
  
  def test_story_totals_returns_stories_in_state()
    provide_stories()
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
  
  def test_state_returns_current_state()
    provide_stories()
    assert_equal("created",Story.find_by_ticket_id(1).state)
    assert_equal("started",Story.find_by_ticket_id(2).state)
    assert_equal("started",Story.find_by_ticket_id(3).state)
    assert_equal("finished",Story.find_by_ticket_id(4).state)
    assert_equal("finished",Story.find_by_ticket_id(5).state)
    assert_equal("delivered",Story.find_by_ticket_id(6).state)
    assert_equal("accepted",Story.find_by_ticket_id(7).state)
    assert_equal("accepted",Story.find_by_ticket_id(8).state)
    assert_equal("accepted",Story.find_by_ticket_id(9).state)
  end
  
  def test_update_state_updates_state()
    provide_stories()
    assert_equal("created",Story.find_by_ticket_id(1).state)
    Story.find_by_ticket_id(1).update_state("started","2013/01/31 13:37:51 UTC")
    assert_equal("started",Story.find_by_ticket_id(1).state)
    assert_equal(true,Story.find_by_ticket_id(1).created?)
    assert_equal(true,Story.find_by_ticket_id(1).started?)
    assert_equal(false,Story.find_by_ticket_id(1).finished?)
    assert_equal(false,Story.find_by_ticket_id(1).delivered?)
    assert_equal(false,Story.find_by_ticket_id(1).accepted?)
    assert_equal(false,Story.find_by_ticket_id(1).rejected?)
    
    # Check we can skip a stage (In case we miss an update)
    Story.find_by_ticket_id(1).update_state("delivered","2014/01/31 13:37:51 UTC")
    assert_equal("delivered",Story.find_by_ticket_id(1).state)
    assert_equal(true,Story.find_by_ticket_id(1).created?)
    assert_equal(true,Story.find_by_ticket_id(1).started?)
    assert_equal(true,Story.find_by_ticket_id(1).finished?)
    assert_equal(true,Story.find_by_ticket_id(1).delivered?)
    assert_equal(false,Story.find_by_ticket_id(1).accepted?)
    assert_equal(false,Story.find_by_ticket_id(1).rejected?)
    
    # Check that we can't go back a stage
    Story.find_by_ticket_id(1).update_state("started","2014/01/31 13:37:51 UTC")
    assert_equal("delivered",Story.find_by_ticket_id(1).state)
    assert_equal(true,Story.find_by_ticket_id(1).created?)
    assert_equal(true,Story.find_by_ticket_id(1).started?)
    assert_equal(true,Story.find_by_ticket_id(1).finished?)
    assert_equal(true,Story.find_by_ticket_id(1).delivered?)
    assert_equal(false,Story.find_by_ticket_id(1).accepted?)
    assert_equal(false,Story.find_by_ticket_id(1).rejected?)
  end
  
  def test_reject_clears_states()
    provide_stories()
    assert_equal(0,Story.find_by_ticket_id(6).rejection_count)
    Story.find_by_ticket_id(6).reject("2014/01/31 13:37:51 UTC")
    assert_equal("rejected",Story.find_by_ticket_id(6).state)
    assert_equal(true,Story.find_by_ticket_id(6).created?)
    assert_equal(false,Story.find_by_ticket_id(6).started?)
    assert_equal(false,Story.find_by_ticket_id(6).finished?)
    assert_equal(false,Story.find_by_ticket_id(6).delivered?)
    assert_equal(false,Story.find_by_ticket_id(6).accepted?)
    assert_equal(1,Story.find_by_ticket_id(6).rejection_count)
    Story.find_by_ticket_id(6).reject("2015/01/31 13:37:51 UTC")
    assert_equal(2,Story.find_by_ticket_id(6).rejection_count)
  end
  
  def provide_stories()
    Story.create!(
    :ticket_id=>1,
    :name => 'foo',
    :created => '2012-01-31 [14:31:32]',
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>2,
    :name => 'bar',
    :created => '2012-01-31 [14:31:33]',
    :started => '2012-01-31 [14:32:33]',
    :ticket_type => 'feature')
    Story.create!(
    :ticket_id=>3,
    :name => 'baz',
    :created => '2012-01-31 [14:31:34]',
    :started => '2012-01-31 [14:32:33]',
    :ticket_type => 'chore')
    Story.create!(
    :ticket_id=>4,
    :name => 'bax',
    :created => '2012-01-31 [14:31:35]',
    :started => '2012-01-31 [14:32:33]',
    :finished => '2012-01-31 [14:33:33]',
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>5,
    :name => 'box',
    :created => '2012-01-31 [14:31:36]',
    :started => '2012-01-31 [14:32:33]',
    :finished => '2012-01-31 [14:33:33]',
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>6,
    :name => 'fox',
    :created => '2012-01-31 [14:31:37]',
    :started => '2012-01-31 [14:32:33]',
    :finished => '2012-01-31 [14:33:33]',
    :delivered => '2012-01-31 [14:35:33]', 
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>7,
    :name => 'fix',
    :created => '2012-01-31 [14:31:38]',
    :started => '2012-01-31 [14:32:33]',
    :finished => '2012-01-31 [14:33:33]',
    :delivered => '2012-01-31 [14:35:33]',
    :accepted =>  '2012-01-31 [14:36:33]',
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>8,
    :name => 'fax',
    :created => '2012-01-31 [14:31:39]',
    :started => '2012-01-31 [14:32:33]',
    :finished => '2012-01-31 [14:33:33]',
    :delivered => '2012-01-31 [14:35:33]',
    :accepted =>  '2012-01-31 [14:36:33]',
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>9,
    :name => 'boo',
    :created => '2012-01-31 [14:31:40]',
    :started => '2012-01-31 [14:32:33]',
    :finished => '2012-01-31 [14:33:33]',
    :delivered => '2012-01-31 [14:35:33]',
    :accepted =>  '2012-01-31 [14:36:33]',
    :ticket_type => 'bug')
  end
  
  def test_post()
    post '/','test'
    assert_equal '', last_response.body
  end
  
  def test_create_events_create_a_story()
    File.open("./test/xml/create.xml") do |file|
      post '/',file.read()
    end
    story = Story.find_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state)
    assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
  end
  
  def test_update_events_update_a_story()
    File.open("./test/xml/create.xml") do |file|
      post '/',file.read()
    end
    story = Story.find_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state)
    assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
    
    File.open("./test/xml/start.xml") do |file|
      post '/',file.read()
    end
    story.reload()
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('started',story.state)
    assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
    assert_equal(DateTime.parse('2012/02/01 11:05:51 UTC'),story.started)
    File.open("./test/xml/accepted.xml") do |file|
      post '/',file.read()
    end
    story.reload()
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('accepted',story.state)
    assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
    assert_equal(DateTime.parse('2012/02/01 11:05:51 UTC'),story.started)
    assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.finished)
    assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.delivered)
    assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.accepted)
  end
  
  def test_other_events_have_no_effect()
    File.open("./test/xml/create.xml") do |file|
      post '/',file.read()
    end
    story = Story.find_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state)
    assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
    
    File.open("./test/xml/note.xml")do |file|
      post '/',file.read()
    end
    story = Story.find_by_ticket_id(1)
    assert_equal('Study the progress of a ticket through the system',story.name)
    assert_equal('created',story.state)
    assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
  
  end
  
  def test_uncreated_tickets_get_default_data()
    File.open("./test/xml/start2.xml") do |file|
      post '/',file.read()
    end
    story = Story.find_by_ticket_id(2)
    assert_equal('Unknown story',story.name)
    assert_equal('started',story.state)
    assert_equal(DateTime.parse('01/01/2000'),story.created)
    assert_equal(DateTime.parse('2012/02/01 14:56:37 UTC'),story.started)
    assert_equal('unknown',story.ticket_type)
  end
  
  def test_api_calls()
    assert $SETTINGS["api_token"]
    resource_uri = URI.parse("http://www.pivotaltracker.com/services/v3/projects/#{$SETTINGS["project_id"]}/stories/#{$SETTINGS["test_ticket_id"]}")
    data = PtApi.fetch_xml(resource_uri,$SETTINGS["api_token"])
    assert PtApi.check_xml(data,$SETTINGS["test_ticket_id"])
  end
  
  def test_link_to_populate_page_when_database_empty()
    authorize 'admin', 'admin'
    get '/'
    assert_equal 200, last_response.status
    assert last_response.body.include?("<a href='populate'>")
  end
  
  def test_populate_functions_work()
   assert Story.count() == 0
   assert $SETTINGS['api_token'] != nil
   message = PtApi.populate_database($SETTINGS['project_id'],$SETTINGS['api_token'],'all')
   assert Story.count() > 0
   story = Story.find_by_ticket_id($SETTINGS["test_ticket_id"])
   assert (story.name == $SETTINGS["test_ticket_name"])
  end
  
  def test_incomplete_tickets_returns_incomplete_tickets()
    ['1','2','3','6','9'].each do |ticket_id|
      Story.create!( # Create story with placeholders
        :ticket_id => ticket_id,
        :name => "Unknown story",
        :created => DateTime.parse('01/01/2000'),
        :ticket_type => 'unknown'
        )
      end
      ['4','5','7','8'].each do |ticket_id|
        Story.create!( # Create story with placeholders
          :ticket_id => ticket_id,
          :name => "Valid story",
          :created => DateTime.parse('01/01/2001'),
          :ticket_type => 'bug'
          )
        end
    incomplete = Story.incomplete()
    assert incomplete.length == 5
    assert incomplete.include?(1)
    assert incomplete.include?(6)
    assert !incomplete.include?(4)
    assert !incomplete.include?(8)
  end
  
  def test_update_stories_updates()
    File.open("./test/xml/start2.xml") do |file|
      post '/',file.read()
    end
    incomplete = Story.incomplete()
    assert incomplete.include?(2)
    story = Story.find_by_ticket_id(2)
    story.ticket_id=$SETTINGS["test_ticket_id"]
    story.save()
    assert_equal('Unknown story',story.name)
    PtApi.populate_database($SETTINGS['project_id'],$SETTINGS['api_token'],incomplete)
    story.reload()
    assert story.name == $SETTINGS["test_ticket_name"]
  end
  
  def test_stories_can_be_deleted()
    provide_stories()
    story = Story.find_by_ticket_id(3)
    story.delete('2007-08-01') # Delete a story
    story.reload()
    assert_equal(true, story.deleted?)
    assert_equal('deleted',story.state()) 
    assert_equal(8,Story.total.length) # It doesn't count
    assert_equal(9,Story.count()) # But it is not gone forever
    assert_equal(1,Story.started.length)
  end
  
  def test_post_calls_delete_stories()
    provide_stories()
    File.open("./test/xml/delete.xml") do |file|
      post '/',file.read()
    end
    story = Story.find_by_ticket_id(3)
    story.deleted?
  end
  
  def teardown
    Story.delete_all()
  end
  
end