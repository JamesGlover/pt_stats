ENV['RACK_ENV'] = 'test'

if ARGV.include?('--clear')
  $CLEAR = true
end

if ARGV.include?('--no-api')
  $NO_API = true
  puts "Remote API calls will not be tested."
end

require 'rubygems'
require_relative '../web'
require 'test/unit'
require 'rack/test'

$SETTINGS['api_token']=ARGV[ARGV.index('-a')+1] if ARGV.index('-a')!= nil

if $SETTINGS['api_token'] != nil
  puts "Using API key: #{$SETTINGS['api_token']}"
else
  puts "No API key provided. Either edit /config.yml or provide the argument -a APIKEYHERE"
end

class MyUnitTests < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup

      if Story.count > 0
        if $CLEAR
          Story.destroy_all()
        else
          puts "WARNING! Database already populated with test entry"
          puts "Use -- --clear to automatically remove tickets"
          puts "Terminating"
          Process::exit
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
    post '/bucket'
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
    story = Story.find_last_by_ticket_id(1)
    assert_equal(1,story.ticket_id)
    assert_equal('foo',story.name)
    assert_equal(DateTime.parse('2012-01-31 [14:31:32]'),story.created)
    assert_equal('bug',story.ticket_type)
  end
  
  def test_method_accessors_return_stories()
    provide_stories()
    assert_equal(1,Story.created(0).length)
    assert_equal(2,Story.started(0).length)
    assert_equal(2,Story.finished(0).length)
    assert_equal(1,Story.delivered(0).length)
    assert_equal(3,Story.accepted(0).length)
    assert_equal(9,Story.total(0).length)
  end
  
  def test_iteration_counts_are_correct()
    story=Story.create!(
    :ticket_id=>1,
    :created => '2012-02-09 [14:31:32]')
    assert_equal(1,Story.created(4).length)
    assert_equal(0,Story.rejected(4).length)
    assert_equal(0,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(0,Story.total(4).length)
    
    story.started='2012-02-09 [14:31:33]'
    story.save()
    assert_equal(0,Story.created(4).length)
    assert_equal(0,Story.rejected(4).length)
    assert_equal(1,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

    story.finished='2012-02-09 [14:31:34]'
    story.save()
    assert_equal(0,Story.created(4).length)
    assert_equal(0,Story.rejected(4).length)
    assert_equal(0,Story.started(4).length)
    assert_equal(1,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

    story.delivered='2012-02-09 [14:31:35]'
    story.save()
    assert_equal(0,Story.created(4).length)
    assert_equal(0,Story.rejected(4).length)
    assert_equal(0,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(1,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

    story.accepted='2012-02-09 [14:31:36]'
    story.save()
    assert_equal(0,Story.created(4).length)
    assert_equal(0,Story.rejected(4).length)
    assert_equal(0,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(1,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

    story.reject('2012-02-09 [14:31:37]')
    assert_equal(0,Story.created(4).length)
    assert_equal(1,Story.rejected(4).length)
    assert_equal(0,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

    story.update_state('started','2012-02-09 [14:31:38]')
    assert_equal(0,Story.created(4).length)
    assert_equal(0,Story.rejected(4).length)
    assert_equal(1,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

    story = Story.find_last_by_ticket_id(1)
    story.reject('2012-02-09 [14:31:39]')
    assert_equal(0,Story.created(4).length)
    assert_equal(1,Story.rejected(4).length)
    assert_equal(0,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

    story.update_state('started','2012-02-09 [14:31:40]')
    assert_equal(0,Story.created(4).length)
    assert_equal(0,Story.rejected(4).length)
    assert_equal(1,Story.started(4).length)
    assert_equal(0,Story.finished(4).length)
    assert_equal(0,Story.delivered(4).length)
    assert_equal(0,Story.accepted(4).length)
    assert_equal(1,Story.total(4).length)

  end
  
  def test_iteration_counts_are_correct_2()
    Story.create!(
    :ticket_id=>1,
    :created => '2012-02-09 [14:31:32]')
    Story.create!(
    :ticket_id=>9,
    :created => '1266-02-09 [14:31:32]')
    Story.create!(
    :ticket_id=>10,
    :created => '3266-02-09 [14:31:32]')
    Story.create!(
    :ticket_id=>2,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>3,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]')
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
    :rejected => '2012-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:37]')
    Story.create!(
    :ticket_id=>8,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>8,
    :created => '2012-02-09 [14:31:32]',
    :started => '2036-01-04 [12:23:11]')
    Story.create!(
    :ticket_id=>11,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :rejected => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>12,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2012-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')  
    Story.create!(
    :ticket_id=>13,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2012-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>14,
    :created => '2012-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>15,
    :created => '2012-02-09 [14:31:32]',
    :started => '2036-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>16,
    :created => '1066-02-09 [14:31:32]',
    :started => '2036-02-09 [14:31:33]',
    :finished => '2036-02-09 [14:31:34]',
    :delivered => '2036-02-09 [14:31:35]',
    :accepted => '2036-02-09 [14:31:36]')
    # Totals
    assert_equal(3,Story.created(0).length, "With: #{Story.created(0).inspect}")
    assert_equal(2,Story.rejected(0).length, "With: #{Story.rejected(0).inspect}")
    assert_equal(3,Story.started(0).length, "With: #{Story.started(0).inspect}")
    assert_equal(1,Story.finished(0).length,  "With: #{Story.finished(0).inspect}")
    assert_equal(1,Story.delivered(0).length,  "With: #{Story.delivered(0).inspect}")
    assert_equal(6,Story.accepted(0).length,  "With: #{Story.accepted(0).inspect}")
    assert_equal(16,Story.total(0).length,  "With: #{Story.total(0).inspect}")
    # Iteration
    assert_equal(2,Story.created(4).length, "With: #{Story.created(4).inspect}")
    assert_equal(2,Story.rejected(4).length, "With: #{Story.rejected(4).inspect}")
    assert_equal(3,Story.started(4).length, "With: #{Story.started(4).inspect}")
    assert_equal(2,Story.finished(4).length,  "With: #{Story.finished(4).inspect}")
    assert_equal(3,Story.delivered(4).length,  "With: #{Story.delivered(4).inspect}")
    assert_equal(1,Story.accepted(4).length,  "With: #{Story.accepted(4).inspect}")
    assert_equal(11,Story.total(4).length,  "With: #{Story.total(4).inspect}")
  end
  
  def test_iteration_counts_are_correct_5()
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
    assert_equal(0,Story.created(0).length, "With: #{Story.created(0).inspect}")
    assert_equal(5,Story.rejected(0).length, "With: #{Story.rejected(0).inspect}")
    assert_equal(0,Story.started(0).length, "With: #{Story.started(0).inspect}")
    assert_equal(0,Story.finished(0).length,  "With: #{Story.finished(0).inspect}")
    assert_equal(0,Story.delivered(0).length,  "With: #{Story.delivered(0).inspect}")
    assert_equal(0,Story.accepted(0).length,  "With: #{Story.accepted(0).inspect}")
    assert_equal(5,Story.total(0).length,  "With: #{Story.total(0).inspect}")
    # Iteration
    assert_equal(1,Story.created(4).length, "With: #{Story.created(4).inspect}")
    assert_equal(3,Story.rejected(4).length, "With: #{Story.rejected(4).inspect}")
    assert_equal(0,Story.started(4).length, "With: #{Story.started(4).inspect}")
    assert_equal(0,Story.finished(4).length,  "With: #{Story.finished(4).inspect}")
    assert_equal(0,Story.delivered(4).length,  "With: #{Story.delivered(4).inspect}")
    assert_equal(0,Story.accepted(4).length,  "With: #{Story.accepted(4).inspect}")
    assert_equal(3,Story.total(4).length,  "With: #{Story.total(4).inspect}")
  end
  
  def test_iteration_counts_are_correct_3()
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
    :created => '1066-02-09 [14:31:32]',
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
    :created => '1066-02-09 [14:31:32]',
    :started => '2036-02-09 [14:31:33]',
    :finished=> '2036-02-09 [14:31:34]')
    Story.create!(
    :ticket_id=>6,
    :created => '1066-02-09 [14:31:32]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>6,
    :created => '1066-02-09 [14:31:32]',
    :started => '1666-02-09 [14:31:33]',
    :rejected => '1667-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>6,
    :created => '1066-02-09 [14:31:32]',
    :started => '2036-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>7,
    :created => '1066-02-09 [14:31:32]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7,
    :created => '1066-02-09 [14:31:32]',
    :started => '1666-02-09 [14:31:33]',
    :rejected => '1667-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>7,
    :created => '1066-02-09 [14:31:32]',
    :started => '2012-02-09 [14:31:33]')
    # Totals
    assert_equal(0,Story.created(0).length, "With: #{Story.created(0).inspect}")
    assert_equal(0,Story.rejected(0).length, "With: #{Story.rejected(0).inspect}")
    assert_equal(2,Story.started(0).length, "With: #{Story.started(0).inspect}")
    assert_equal(1,Story.finished(0).length,  "With: #{Story.finished(0).inspect}")
    assert_equal(1,Story.delivered(0).length,  "With: #{Story.delivered(0).inspect}")
    assert_equal(3,Story.accepted(0).length,  "With: #{Story.accepted(0).inspect}")
    assert_equal(7,Story.total(0).length,  "With: #{Story.total(0).inspect}")
    # Iteration
    assert_equal(0,Story.created(4).length, "With: #{Story.created(4).inspect}")
    assert_equal(3,Story.rejected(4).length, "With: #{Story.rejected(4).inspect}")
    assert_equal(2,Story.started(4).length, "With: #{Story.started(4).inspect}")
    assert_equal(0,Story.finished(4).length,  "With: #{Story.finished(4).inspect}")
    assert_equal(0,Story.delivered(4).length,  "With: #{Story.delivered(4).inspect}")
    assert_equal(0,Story.accepted(4).length,  "With: #{Story.accepted(4).inspect}")
    assert_equal(5,Story.total(4).length,  "With: #{Story.total(4).inspect}")
  end
  
  def test_iteration_counts_are_correct_4()
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
    Story.create!(
    :ticket_id=>2,
    :created => '1066-02-09 [14:31:32]',
    :started => '1066-02-09 [14:31:33]',
    :finished => '1066-02-09 [14:31:34]',
    :delivered => '1066-02-09 [14:31:35]',
    :rejected => '1066-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>2,
    :created => '1066-02-09 [14:31:32]',
    :started => '1566-02-09 [14:31:33]',
    :finished => '1566-02-09 [14:31:34]',
    :delivered => '1566-02-09 [14:31:35]',
    :rejected => '1566-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>2,
    :created => '1066-02-09 [14:31:32]',
    :started => '1666-02-09 [14:31:33]',
    :finished => '1666-02-09 [14:31:34]',
    :delivered => '1666-02-09 [14:31:35]',
    :rejected => '1666-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>2,
    :created => '1066-02-09 [14:31:32]',
    :started => '1766-02-09 [14:31:33]',
    :finished => '1766-02-09 [14:31:34]',
    :delivered => '1766-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>2,
    :created => '1066-02-09 [14:31:32]',
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
    :created => '1066-02-09 [14:31:32]',
    :started => '1566-02-09 [14:31:33]',
    :finished => '1566-02-09 [14:31:34]',
    :delivered => '1566-02-09 [14:31:35]',
    :rejected => '1566-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>3,
    :created => '1066-02-09 [14:31:32]',
    :started => '1666-02-09 [14:31:33]',
    :finished => '1666-02-09 [14:31:34]',
    :delivered => '1666-02-09 [14:31:35]',
    :rejected => '1666-02-09 [14:31:36]')
    Story.create!(
    :ticket_id=>3,
    :created => '1066-02-09 [14:31:32]',
    :started => '1766-02-09 [14:31:33]',
    :finished => '1766-02-09 [14:31:34]',
    :delivered => '1766-02-09 [14:31:35]',
    :rejected => '2012-02-09 [14:31:33]')
    Story.create!(
    :ticket_id=>3,
    :created => '1066-02-09 [14:31:32]',
    :started => '2032-02-09 [14:33:33]')
    # Totals
    assert_equal(0,Story.created(0).length, "With: #{Story.created(0).inspect}")
    assert_equal(1,Story.rejected(0).length, "With: #{Story.rejected(0).inspect}")
    assert_equal(2,Story.started(0).length, "With: #{Story.started(0).inspect}")
    assert_equal(0,Story.finished(0).length,  "With: #{Story.finished(0).inspect}")
    assert_equal(0,Story.delivered(0).length,  "With: #{Story.delivered(0).inspect}")
    assert_equal(0,Story.accepted(0).length,  "With: #{Story.accepted(0).inspect}")
    assert_equal(3,Story.total(0).length,  "With: #{Story.total(0).inspect}")

    # Iteration
    assert_equal(0,Story.created(4).length, "With: #{Story.created(4).inspect}")
    assert_equal(2,Story.rejected(4).length, "With: #{Story.rejected(4).inspect}")
    assert_equal(1,Story.started(4).length, "With: #{Story.started(4).inspect}")
    assert_equal(0,Story.finished(4).length,  "With: #{Story.finished(4).inspect}")
    assert_equal(0,Story.delivered(4).length,  "With: #{Story.delivered(4).inspect}")
    assert_equal(0,Story.accepted(4).length,  "With: #{Story.accepted(4).inspect}")
    assert_equal(3,Story.total(4).length,  "With: #{Story.total(4).inspect}")

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
        assert_equal("created",Story.find_last_by_ticket_id(1).state)
        assert_equal("started",Story.find_last_by_ticket_id(2).state)
        assert_equal("started",Story.find_last_by_ticket_id(3).state)
        assert_equal("finished",Story.find_last_by_ticket_id(4).state)
        assert_equal("finished",Story.find_last_by_ticket_id(5).state)
        assert_equal("delivered",Story.find_last_by_ticket_id(6).state)
        assert_equal("accepted",Story.find_last_by_ticket_id(7).state)
        assert_equal("accepted",Story.find_last_by_ticket_id(8).state)
        assert_equal("accepted",Story.find_last_by_ticket_id(9).state)
      end
      
      def test_update_state_updates_state()
        provide_stories()
        assert_equal("created",Story.find_last_by_ticket_id(1).state)
        Story.find_last_by_ticket_id(1).update_state("started","2013/01/31 13:37:51 UTC")
        assert_equal("started",Story.find_last_by_ticket_id(1).state)
        assert_equal(true,Story.find_last_by_ticket_id(1).created?)
        assert_equal(true,Story.find_last_by_ticket_id(1).started?)
        assert_equal(false,Story.find_last_by_ticket_id(1).finished?)
        assert_equal(false,Story.find_last_by_ticket_id(1).delivered?)
        assert_equal(false,Story.find_last_by_ticket_id(1).accepted?)
        assert_equal(false,Story.find_last_by_ticket_id(1).rejected?)
        
        # Check we can skip a stage (In case we miss an update)
        Story.find_last_by_ticket_id(1).update_state("delivered","2014/01/31 13:37:51 UTC")
        assert_equal("delivered",Story.find_last_by_ticket_id(1).state)
        assert_equal(true,Story.find_last_by_ticket_id(1).created?)
        assert_equal(true,Story.find_last_by_ticket_id(1).started?)
        assert_equal(false,Story.find_last_by_ticket_id(1).finished?)
        assert_equal(true,Story.find_last_by_ticket_id(1).delivered?)
        assert_equal(false,Story.find_last_by_ticket_id(1).accepted?)
        assert_equal(false,Story.find_last_by_ticket_id(1).rejected?)
        
        # Check that we can't go back a stage
        Story.find_last_by_ticket_id(1).update_state("started","2014/01/31 13:37:51 UTC")
        assert_equal("delivered",Story.find_last_by_ticket_id(1).state)
        assert_equal(true,Story.find_last_by_ticket_id(1).created?)
        assert_equal(true,Story.find_last_by_ticket_id(1).started?)
        assert_equal(false,Story.find_last_by_ticket_id(1).finished?)
        assert_equal(true,Story.find_last_by_ticket_id(1).delivered?)
        assert_equal(false,Story.find_last_by_ticket_id(1).accepted?)
        assert_equal(false,Story.find_last_by_ticket_id(1).rejected?)
      end
      
      def test_starting_rejected_stories_provides_new_story()
        provide_stories()
        assert_equal(0,Story.find_last_by_ticket_id(6).rejection_count)
        Story.find_last_by_ticket_id(6).reject("2014/01/31 13:37:51 UTC")
        assert_equal("rejected",Story.find_last_by_ticket_id(6).state)
        Story.find_last_by_ticket_id(6).update_state('started','2014/06/03')
        assert_equal(2,Story.find_all_by_ticket_id(6).length)
        assert_equal("started",Story.find_last_by_ticket_id(6).state)
        assert_equal(true,Story.find_last_by_ticket_id(6).created?)
        assert_equal(true,Story.find_last_by_ticket_id(6).started?)
        assert_equal(false,Story.find_last_by_ticket_id(6).finished?)
        assert_equal(false,Story.find_last_by_ticket_id(6).delivered?)
        assert_equal(false,Story.find_last_by_ticket_id(6).accepted?)
        assert_equal(1,Story.find_last_by_ticket_id(6).rejection_count)
        #assert Story.where("rejected IS NOT NULL").first.finished?
        Story.find_last_by_ticket_id(6).reject("2015/01/31 13:37:51 UTC")
        Story.find_last_by_ticket_id(6).update_state('started','2062/01/03')
        assert_equal(3,Story.find_all_by_ticket_id(6).length)
        assert_equal(2,Story.find_last_by_ticket_id(6).rejection_count)
      end
      
      def test_delayed_tickets_on_rejected_stories()
        original = Story.create(
        :ticket_id=>1,
        :name => 'foo',
        :created => '1983-01-31 [14:31:32]',
        :ticket_type => 'bug')
        original.update_state("started","01/01/2000")
        original.reject("01/12/2000")
        second = Story.find_last_by_ticket_id(1)
        second.update_state("finished","01/06/2000")
        original.reload()
        second.reload()
        assert_equal(true,original.rejected?)
        assert_equal(true,original.finished?)
        assert_equal(true,second.finished?)
        assert_equal(true,second.started?)
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
        post '/bucket','test'
        assert_equal '', last_response.body
      end
      
      def test_create_events_create_a_story()
        File.open("./test/xml/create.xml") do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(1)
        assert_equal('Study the progress of a ticket through the system',story.name)
        assert_equal('created',story.state)
        assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
      end
      
      def test_update_events_update_a_story()
        File.open("./test/xml/create.xml") do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(1)
        assert_equal('Study the progress of a ticket through the system',story.name)
        assert_equal('created',story.state)
        assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
        
        File.open("./test/xml/start.xml") do |file|
          post '/bucket',file.read()
        end
        story.reload()
        assert_equal('Study the progress of a ticket through the system',story.name)
        assert_equal('started',story.state)
        assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
        assert_equal(DateTime.parse('2012/02/01 11:05:51 UTC'),story.started)
        File.open("./test/xml/accepted.xml") do |file|
          post '/bucket',file.read()
        end
        story.reload()
        assert_equal('Study the progress of a ticket through the system',story.name)
        assert_equal('accepted',story.state)
        assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
        assert_equal(DateTime.parse('2012/02/01 11:05:51 UTC'),story.started)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.accepted)
      end
      
      def test_other_events_have_no_effect()
        File.open("./test/xml/create.xml") do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(1)
        assert_equal('Study the progress of a ticket through the system',story.name)
        assert_equal('created',story.state)
        assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
        
        File.open("./test/xml/note.xml")do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(1)
        assert_equal('Study the progress of a ticket through the system',story.name)
        assert_equal('created',story.state)
        assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
      end
      
      def test_activities_can_be_used_for_population()
        File.open("./test/xml/activities.xml") do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(24220815)
        assert_equal('Study the progress of a ticket through the system',story.name)
        assert_equal('accepted',story.state)
        assert_equal(DateTime.parse('2012/01/31 13:37:51 UTC'),story.created)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.accepted)
      end
      
      def test_uncreated_tickets_get_default_data()
        File.open("./test/xml/start2.xml") do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(2)
        assert_equal('Unknown story',story.name)
        assert_equal('started',story.state)
        assert_equal(nil,story.created)
        assert_equal(DateTime.parse('2012/02/01 14:56:37 UTC'),story.started)
        assert_equal('unknown',story.ticket_type)
      end
      
      def test_api_calls()
        return nil if $NO_API
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
       return nil if $NO_API
       assert Story.count() == 0
       assert $SETTINGS['api_token'] != nil
       PtApi.populate_database([],$SETTINGS['project_id'],$SETTINGS['api_token'],'all')
       assert Story.count() > 0
       story = Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"])
       assert_equal($SETTINGS["test_ticket_name"],story.name)
      end
      
      def test_incomplete_tickets_returns_incomplete_tickets()
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
          post '/bucket',file.read()
        end
        incomplete = Story.incomplete()
        assert incomplete.include?(2)
        story = Story.find_last_by_ticket_id(2)
        story.ticket_id=$SETTINGS["test_ticket_id"]
        story.save()
        assert_equal('Unknown story',story.name)
        incomplete = Story.incomplete()
        return nil if $NO_API
        PtApi.populate_database([],$SETTINGS['project_id'],$SETTINGS['api_token'],incomplete)
        story.reload()
        assert_equal($SETTINGS['test_ticket_name'], story.name)
      end
      
      def test_stories_can_be_deleted()
        provide_stories()
        story = Story.find_last_by_ticket_id(3)
        story.delete('2007-08-01') # Delete a story
        story.reload()
        assert_equal(true, story.deleted?)
        assert_equal('deleted',story.state()) 
        assert_equal(8,Story.total(0).length) # It doesn't count
        assert_equal(9,Story.count()) # But it is not gone forever
        assert_equal(1,Story.started(0).length)
      end
      
      def test_delete_deletes_all_tickets_with_same_id()
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
        assert_equal(0,Story.total(0).length)
        Story.find_all_by_ticket_id(1).each do |s|
          assert s.deleted?
        end
      end
      
      def test_post_calls_delete_stories()
        provide_stories()
        File.open("./test/xml/delete.xml") do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(3)
        story.deleted?
      end
      
      def test_scan_for_all_deleted_stories()
        return nil if $NO_API
        provide_stories()
        Story.create!(:ticket_id=>$SETTINGS["test_ticket_id"])
        PtApi.flag_deleted_items([],$SETTINGS['project_id'],$SETTINGS['api_token'],'all')
        assert Story.find_last_by_ticket_id(2).deleted?
        assert Story.find_last_by_ticket_id(4).deleted?
        assert Story.find_last_by_ticket_id(9).deleted?
        assert !Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"]).deleted?
      end
      
      def test_scan_for_specific_deleted_stories()
        return nil if $NO_API
        provide_stories()
        Story.create(:ticket_id=>$SETTINGS["test_ticket_id"])
        PtApi.flag_deleted_items([],$SETTINGS['project_id'],$SETTINGS['api_token'],"2,4,#{$SETTINGS["test_ticket_id"]}")
        assert Story.find_last_by_ticket_id(2).deleted?
        assert Story.find_last_by_ticket_id(4).deleted?
        assert !Story.find_last_by_ticket_id(9).deleted?
        assert !Story.find_last_by_ticket_id($SETTINGS["test_ticket_id"]).deleted?
      end
      
      def test_malformed_posts_fail_cleanly()
        provide_stories()
        Story.find_last_by_ticket_id(1).destroy
        File.open("./test/xml/create.xml") do |file|
          post '/bucket',file.read()
        end
        File.open("./test/xml/accepted.xml") do |file|
          post '/bucket',file.read()
        end
        File.open("./test/xml/start.xml") do |file|
          post '/bucket',file.read()
        end
        File.open("./test/xml/start2.xml") do |file|
          post '/bucket',file.read()
        end
        File.open("./test/xml/nonsense.xml") do |file|
          post '/bucket',file.read()
        end
        File.open("./test/xml/invalid.xml") do |file|
          post '/bucket',file.read()
        end
        story = Story.find_last_by_ticket_id(1)
        assert_equal('accepted',story.state)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.accepted)
        assert_equal(DateTime.parse('2012/02/01 11:05:51 UTC'),story.started)
      end
      
      def test_changes_to_story_update_handle_edits()
        story = Story.create!(:ticket_id=>1, :name=>"Replace this", :ticket_type=>'feature', :created=>DateTime.parse('2012/02/01 12:03:36 UTC'))
        assert_equal("Replace this",story.name)
        assert_equal('feature',story.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.created)
        assert_equal('created',story.state)
        File.open("./test/xml/update1.xml") do |file|
          post '/bucket',file.read()
        end
        story.reload()
        assert_equal("Replace this",story.name)
        assert_equal('bug',story.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.created)
        assert_equal('created',story.state)
        File.open("./test/xml/update2.xml") do |file|
          post '/bucket',file.read()
        end
        story.reload()
        assert_equal("With a new name",story.name)
        assert_equal('bug',story.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story.created)
        assert_equal('created',story.state)
      end
      
      def test_changes_to_story_update_handle_edits_with_rejects()
        story_a = Story.create!(:ticket_id=>1, :name=>"Replace this", :ticket_type=>'feature', :created=>DateTime.parse('2012/02/01 12:03:36 UTC'), :started=>DateTime.parse('2012/02/01 12:03:37 UTC'),
          :rejected=>DateTime.parse('2012/02/01 12:03:38 UTC'))
        story_b = Story.create!(:ticket_id=>1, :name=>"Replace this", :ticket_type=>'feature', :created=>DateTime.parse('2012/02/01 12:03:36 UTC'), :started=>DateTime.parse('2012/02/01 12:03:39 UTC'))
        assert_equal("Replace this",story_b.name)
        assert_equal('feature',story_b.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story_b.created)
        assert_equal('started',story_b.state)
        assert_equal("Replace this",story_a.name)
        assert_equal('feature',story_a.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story_a.created)
        assert_equal('rejected',story_a.state)
        File.open("./test/xml/update1.xml") do |file|
          post '/bucket',file.read()
        end
        story_a.reload()
        story_b.reload()
        assert_equal("Replace this",story_b.name)
        assert_equal("Replace this",story_a.name)
        assert_equal('feature',story_a.ticket_type)
        assert_equal('bug',story_b.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story_b.created)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story_a.created)
        assert_equal('started',story_b.state)
        assert_equal('rejected',story_a.state)
        File.open("./test/xml/update2.xml") do |file|
          post '/bucket',file.read()
        end
        story_a.reload()
        story_b.reload()
        assert_equal("With a new name",story_b.name)
        assert_equal('bug',story_b.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story_b.created)
        assert_equal('started',story_b.state)
        assert_equal("Replace this",story_a.name)
        assert_equal('feature',story_a.ticket_type)
        assert_equal(DateTime.parse('2012/02/01 12:03:36 UTC'),story_a.created)
        assert_equal('rejected',story_a.state)
        # And check counts
        assert_equal(0,Story.features(0).length, "With: #{Story.features(0)}")
        assert_equal(1,Story.bugs(0).length,"With: #{Story.bugs(0)}" )
      end
      
      def test_ticket_type_counts_are_correct()
        #Basic tests
        provide_stories()
        assert_equal(7,Story.bugs(0).length)
        assert_equal(1,Story.features(0).length)
        assert_equal(1,Story.chores(0).length)
        assert_equal(0,Story.releases(0).length)
        Story.destroy_all()
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
        assert_equal(1,Story.bugs(0).length)
        assert_equal(1,Story.features(0).length)
        assert_equal(1,Story.chores(0).length)
        assert_equal(1,Story.releases(0).length)
        assert_equal(1,Story.bugs(4).length)
        assert_equal(1,Story.features(4).length)
        assert_equal(1,Story.chores(4).length)
        assert_equal(1,Story.releases(4).length)
        assert_equal(0,Story.bugs(3).length)
        assert_equal(0,Story.features(3).length)
        assert_equal(0,Story.chores(3).length)
        assert_equal(0,Story.releases(3).length)
        #More complicated
        Story.destroy_all()
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
        :created => '2012-02-09 [14:31:32]',
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
        :created => '2012-02-09 [14:31:32]',
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
        assert_equal(16,Story.bugs(0).length,  "With: #{Story.bugs(0).inspect}")
        # Iteration
        assert_equal(11,Story.bugs(4).length,  "With: #{Story.bugs(4).inspect}")
      end
    
  def teardown
    Story.delete_all()
  end
  
end