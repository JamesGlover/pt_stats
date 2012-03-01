module TestHelpers
  
  include SinatraHelpers
  
  def provide_stories()
    Story.create!(
    :ticket_id=>1,
    :name => 'foo',
    :created => previous_iteration(0),
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>2,
    :name => 'bar',
    :created => previous_iteration(1),
    :started => previous_iteration(2),
    :ticket_type => 'feature')
    Story.create!(
    :ticket_id=>3,
    :name => 'baz',
    :created => previous_iteration(3),
    :started => previous_iteration(4),
    :ticket_type => 'chore')
    Story.create!(
    :ticket_id=>4,
    :name => 'bax',
    :created => previous_iteration(5),
    :started => previous_iteration(6),
    :finished => previous_iteration(7),
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>5,
    :name => 'box',
    :created => previous_iteration(8),
    :started => previous_iteration(9),
    :finished => previous_iteration(10),
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>6,
    :name => 'fox',
    :created => previous_iteration(11),
    :started => previous_iteration(12),
    :finished => previous_iteration(13),
    :delivered => previous_iteration(14), 
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>7,
    :name => 'fix',
    :created => previous_iteration(15),
    :started => previous_iteration(16),
    :finished => previous_iteration(17),
    :delivered => previous_iteration(18),
    :accepted =>  previous_iteration(19),
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>8,
    :name => 'fax',
    :created => previous_iteration(20),
    :started => previous_iteration(21),
    :finished => previous_iteration(22),
    :delivered => previous_iteration(23),
    :accepted =>  previous_iteration(24),
    :ticket_type => 'bug')
    Story.create!(
    :ticket_id=>9,
    :name => 'boo',
    :created => previous_iteration(25),
    :started => previous_iteration(26),
    :finished => previous_iteration(27),
    :delivered => previous_iteration(28),
    :accepted =>  previous_iteration(29),
    :ticket_type => 'bug')
  end
  
  def assert_counts(i,expected)
    if i!=0
      i = i.iteration
    else
      i = Iteration.all
    end
    actual = [ Story.created(i).length,
      Story.started(i).length,
      Story.finished(i).length,
      Story.delivered(i).length,
      Story.accepted(i).length,
      Story.rejected(i).length,
      Story.total(i).length,
      Story.count ]
      assert(expected==actual, "Expected:\nCreated:#{expected[0]}, Started:#{expected[1]}, Finished:#{expected[2]}, Delivered:#{expected[3]}, Accepted:#{expected[4]}, Rejected:#{expected[5]}, Total:#{expected[6]}, Count:#{expected[7]}\n Saw:\nCreated:#{actual[0]}, Started:#{actual[1]}, Finished:#{actual[2]}, Delivered:#{actual[3]}, Accepted:#{actual[4]}, Rejected:#{actual[5]}, Total:#{actual[6]}, Count:#{actual[7]}")
  end
  
  def assert_no_messages_raised
    assert Message.count==0, "No messages expected (should be silent), #{Message.count} seen."
  end
  
  def current_iteration(i)
    provide_time('2012-02-09 [14:31:32]',i)
  end

  def previous_iteration(i)
    provide_time('2012-02-01 [14:31:32]',i)
  end
  
  def very_old_iteration(i)
    provide_time('2010-02-01 [14:31:32]',i)
  end
  
  def subsequent_iteration(i)
    provide_time('2012-02-15 [14:31:32]',i)
  end
  
  def provide_time(t,i)
    (t.to_time.advance(:seconds => i)).to_s
  end
  
end