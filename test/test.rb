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
  
  def test_our_server_works()
    get '/'
    assert last_response.ok?
  end
  
  def test_return_includes_template()
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
    get '/'
    assert last_response.ok?
    assert last_response.body.include?($PROJECT_NAME)
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
    get '/'
    assert last_response.ok?
    assert last_response.body.include?("<td id=\"project_created\">1</td>")
    assert last_response.body.include?("<td id=\"project_started\">2</td>")
    assert last_response.body.include?("<td id=\"project_finished\">2</td>")
    assert last_response.body.include?("<td id=\"project_delivered\">1</td>")
    assert last_response.body.include?("<td id=\"project_accepted\">3</td>")
    assert last_response.body.include?("<td id=\"project_total\">9</td>")
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
  
  def test_uncreated_tickets_poll_the_api()
    File.open("./test/xml/start2.xml") do |file|
      post '/',file.read()
    end
    story = Story.find_by_ticket_id(2)
    assert_equal('New Story',story.name)
    assert_equal('started',story.state)
    assert_equal(DateTime.parse('2012/01/31 17:09:06 UTC'),story.created)
    assert_equal(DateTime.parse('2012/02/01 14:56:37 UTC'),story.started)
    assert_equal('feature',story.ticket_type)
  end
  
  def test_api_calls()
    story = PtApi.fetch_story($TEST_TICKET_ID)
    assert_equal($TEST_TICKET_NAME,story.name)
    story.destroy
  end
  
  def teardown
    (1..9).each do |i|
      if Story.find_by_ticket_id(i)
        Story.find_by_ticket_id(i).destroy()
      end
    end
  end
  
end