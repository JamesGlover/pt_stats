module TestHelpers
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
  
  def assert_counts(i,expected)
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
    (DateTime.parse(t).advance(:seconds => i)).to_s
  end
  
end