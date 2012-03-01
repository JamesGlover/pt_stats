module PtApi
  require 'rubygems'
  require 'rexml/document'
  require 'net/http'
  require 'uri'

  def self.incomming(xml)
    return nil if xml.blank?
    xml = ActivityXML.new(xml,[],true)
    xml.parse if xml.is_valid?
  end

  class Request

    attr_reader :messages

    def initialize(id,api_key,id_list)
      @id = id
      @api_key = api_key
      @id_list = id_list
    end

    def fetch(uri)
      retried = false
      begin
        response = Request::PROXY.start(uri.host, uri.port) do |http|
          http.get("#{uri.path}?#{uri.query}", {'X-TrackerToken' => @api_key})
        end
        return StoryXML.new(response.body, @id_list)
      rescue
        if !retried
          puts "Could not connect to API: retrying"
          retried = true
          retry
        else
          puts "Could not connect to API: failed"
          return Error.new
        end
      end
    end

    def paginate
      
      xml = get_page(0)
      return xml if xml==:validationfail 
      1.upto(xml.pages) do |p|
        new_page = get_page(p).data
        if new_page != :validationfail # If we have something, concatenate it
          new_page.root.elements.each('story') do |s|
            xml.data.root.add(s)
          end
        end
      end
      return xml
    end
    
    def get_page(page)
      api_filter="?limit=#{$SETTINGS['page_size']}&offset=#{page*$SETTINGS['page_size']}&filter=includedone:true"
      if @id_list !='all'
        api_filter << '%20id:' << @id_list.join(',')
      end
      xml = fetch(URI.parse("#{$SETTINGS['pt_api']}#{@id}/stories#{api_filter}"))
      if !xml.is_valid?
        return :validationfail
      end
      xml     
    end

  end

  class PopulateDb < Request

    def do
      task = 0
      if @id_list !='all'
        task = 1
      end
      data = paginate
      if data != :validationfail
        data.parse(task)
      end
      self
    end

  end

  class FlagDeleted < Request

    def initialize(id,api,id_list)
      if id_list=='all'
        id_list = Story.total(Iteration.all).map do |story|
          story.ticket_id.to_s
        end
      end
      super(id,api,id_list)
    end

    def do
      data = paginate
      data.flag_deleted
      self
    end

  end

  class XML # An XML document
    attr_reader :data, :messages

    class << self

      def read_file(file) # Test module? Purely for emulation.
        File.open(file) do |f|
          StoryXML.new(f.read)
        end
      end

    end

    # Instance methods

    def initialize(xml,id_list=[],silent=false)
      @id_list = id_list
      @silent = silent
      begin
        @data = REXML::Document.new(xml)
      rescue REXML::ParseException
        Message.new({
          :id => 'parsing_failure',
          :classes => 'bad',
          :title => 'Error: Problems parsing XML',
          :body => "The XML was not parsed correctly."
        },@silent)
      end
    end
    
    def pages
      @pages ||= data.root.nil? ? 0 : (@data.root.attributes['total'].to_f / $SETTINGS['page_size']).ceil-1
    end

    def report(task)
      # Generate report   
      status = 0
      classes = ['good','bad']
      title = ["Stories sucesfully #{['imported','repaired'][task]}","Stories #{['imported','repaired'][task]} with errors"]
      message = "#{@counters[:success]} out of #{@counters[:total]} stories sucesfully #{['imported','repaired'][task]}. "
      if @counters[:parse_error] > 0
        status = 1
        message << "#{@counters[:parse_error]} stories suffered parser errors. Incomplete or malformed data was returned by Pivotal Tracker. "
      end
      if @counters[:create_error] > 0
        status = 1
        message << "#{@counters[:create_error]} stories could not be created. "
      end
      if (@counters[:success] + @counters[:parse_error] + @counters[:create_error]) < @counters[:total].to_i
        status = 1
        message << "Caution! The total number of stories processed does not match that reported by the API."
      end
      if (@id_list!='all' && @id_list.length > 0)
        status = 1
        message << "#{@id_list.length} stories could not be found in the Pivotal Tracker database and may have been deleted.<br/>
        <strong>Missing stories:</strong> #{@id_list.join(',')}<br/>
        Use the 'remove stories' function to remove these stories."
      end
      return {
        :id => ['database_import','database_repair'][task],
        :classes => classes[status],
        :title => title[status],
        :body => message
      }
    end

    def is_valid?
      if @data.to_s == "Access denied.\n"
          error = {
            :status => false,
            :id => 'bad_api',
            :title => 'Error: Access Denied',
            :body => "The server was forbidden from connecting to the Pivotal Tracker API. Check your API key and try again. The database has not been modified."
          }
      elsif @data.nil? || @data.root.nil?
        error = {
          :status => false,
          :body => "The returned document contained no XML data.<br/>
          <strong>Response:</strong> #{data}"
        }
      else
        error = yield if block_given?
      end

      error[:status] = true if error[:status].nil?
      Message.new({
        :id => "#{error[:id]||'bad_xml'}",
        :classes => 'bad',
        :title => "#{error[:title]||'Error: Invalid XML returned'}",
        :body => "#{error[:body]||''}"
      },@silent) if !error[:status]
      
      error[:status]
    end

  end

  class ActivityXML < XML

    def parse
      begin
        return nil unless is_valid? # Fail silently (For now) 
        self.data.elements.to_a('activity|*/activity').reverse.each do |activity|
          Activity.new(activity).parse
        end
      rescue REXML::ParseException
        puts "XML Parsing Failed: #{xml}"
      end
    end

    def is_valid?
      super do
        if (!['activity','activities'].include?(self.data.root.name) )
          {
            :status => false,
            :body => "The document contained unexpected content.<br/>
            <strong>Expected XML root:</strong> activity OR activities<br/>
            <strong>Obserbved XML root:</trong> #{self.data.root.name}"
          }
        else
          {
            :status=>true
          }
        end
      end
    end

  end

  class StoryXML < XML
    def parse(task)
      begin
        @counters = Hash.new(0)
        @counters[:total] = self.data.root.attributes['total']

        self.data.elements.each('stories/story') do |story_data|
          story = NewStory.new(story_data)
          @id_list.delete(story.ticket_id.to_i) if @id_list!='all'
          report = story.parse
          @counters[report] += 1
        end
        
        Message.new(report(task))
      rescue REXML::ParseException
        Message.new({
          :id => 'parsing_failure',
          :classes => 'bad',
          :title => 'Error: Problems parsing XML',
          :body => "The XML was not parsed correctly. Some stories may not have been #{['imported','repaired'][task]}.<br/>
          <strong>Imported:</strong> #{@counters[:success]} of #{@counters[:total]}. <strong>Parse Error:</strong> #{@counters[:parse_error]}. <strong>Create error:</strong> #{@counters[:create_error]}.<br/>
          Any stories not included in this count were unprocessed."
        })
      end
    end

    def is_valid?
      super do
        if (self.data.root.name != 'stories')
          {
            :status => false,
            :body => "The returned document contained unexpected content.<br/>
            <strong>Expected XML root:</strong> stories<br/>
            <strong>Obserbved XML root:</trong> #{self.data.root.name}"
          }
        else
          {
            :status=>true
          }
        end
      end
    end

    def flag_deleted
      total = self.data.root.attributes['total']
      scanned = @id_list.length
      found_ids = index_ids
      begin
        deleted = []
        @id_list.each do |id|
          if !found_ids.include?(id.to_s)
            Story.find_last_by_ticket_id(id).delete(Time.new.to_s)
            deleted << id
          end
        end
      rescue
        Message.new({
          :id => 'deletion_failure',
          :classes => 'bad',
          :title => 'Error: Problems deleting stories',
          :body => "A problem occured while deleting stories.<br/>
          <strong>Tested:</strong> #{scanned} <strong>Against:</strong> #{total} <strong>Flagged deleted:</strong> #{deleted.length}"
        })
        return false
      end
      Message.new({
        :id => 'stories_deleted',
        :classes => 'good',
        :title => 'Stories sucesfully deleted',
        :body => "Of the #{scanned} stories tested, #{deleted.length} could not be found in the Pivitol Tracker database, and have been flagged as deleted.<br/>
        <strong>Flagged IDs:</strong> #{deleted.join(',')}"
      })

    end

    def index_ids
      begin
        self.data.elements.inject('stories/story',[]) do |ids,story|
          if story.elements["id"]
            ids << story.elements["id"].text
          end
        end
      rescue  REXML::ParseException
        Message.new({
          :id => 'parsing_failure',
          :classes => 'bad',
          :title => 'Error: Problems parsing XML',
          :body => "The XML was not parsed correctly. The process has been aborted"
        })
        return false
      end
    end

  end

  class Activity # A single activity in an XML document

    def initialize(data)
      @data = data
      @event_type = @data.elements["event_type"].text
      @date = @data.elements["occurred_at"].text.to_time
    end

    def parse
      return nil if @data.elements["project_id"].text != $SETTINGS['project_id'].to_s # Drop out if we have the wrong project
      begin

        @data.elements.each("stories/story") do |rec_story|
          # For each story: Should only be one
          story = NewStory.new(rec_story)
          @ticket_id = story.ticket_id
          
          db_story = associated_story

          if @event_type == 'story_update' || @event_type =='story_create'
            db_story.update_details(story)
            db_story.update_state(story.current_state,@date) unless story.current_state.blank?
          elsif @event_type == 'story_delete'
            db_story.delete(@date)
          end
        end

      rescue REXML::ParseException
        puts "Parsing fails on XML block: #{@data}"
      end
    end
    
    def associated_story
       # =>       # The earliest rejected ticket that postdates the event, or the active ticket OR  the most recent reject                OR a new story
       Story.where('ticket_id=? AND (rejected > ?)',@ticket_id, @date).order('id ASC').first || Story.find_last_by_ticket_id(@ticket_id) || Story.create!(:ticket_id => @ticket_id)
    end

  end

  class NewStory # A single story in an XML document

    def initialize(data)
      @data = data
    end
    
    def ticket_id
      @ticket_id ||= @data.elements["id"].text
    end
    def name
      @name ||= @data.elements["name"].try(:text)
    end
    def created
      @created ||= @data.elements["created_at"].text.to_time
    end
    def accepted
      @accepted ||= @data.elements["accepted_at"].text.to_time if @data.elements["accepted_at"] != nil
    end
    def ticket_type
      @ticket_type ||= @data.elements["story_type"].try(:text)
    end
    def current_state
      if !defined?(@current_state)
        @current_state = @data.elements["current_state"].try(:text)
        @current_state = 'created' if ['unstarted','unscheduled'].include?(@current_state)
      end
      @current_state
    end

    def parse
      begin
        stories = Story.find_all_by_ticket_id(ticket_id, :order=>'id')
        if stories.empty?
          stories << Story.find_or_create_by_ticket_id(ticket_id)
        end
        stories.each do |db_story| # Repair name and created for all
          db_story.update_details(self)
        end
        db_story = stories.last # Now work with just the most recent
        db_story.ori_created ||= created
        if db_story.state.name != current_state
          latest_date = db_story.last_action
          latest_date = created if latest_date < created
          if ['accepted'].include?(current_state)
            @accepted ||= latest_date
            db_story.update_state(current_state,accepted)
          elsif ['started','finished','delivered','rejected'].include?(current_state)
            db_story.update_state(current_state,latest_date)
          end
        end
        db_story.save
        :success
      rescue ActiveRecord::RecordInvalid
        return :create_error
      rescue REXML::ParseException
        return :parse_error
      end
    end

  end

  class Error
    def is_valid?
      Message.new({
        :id => 'bad_api',
        :classes => 'bad',
        :title => 'Error: Could not connect to API',
        :body => "The server could not connect to the Pivotal Tracker API. Check that your proxy settings are configured correctly, and that the Pivotal Tracker API is operational. The database has not been modified."
      })
      false
    end
  end
end
