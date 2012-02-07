module PtApi
  require 'rubygems'
  require 'rexml/document'
  require 'net/http'
  require 'uri'
  

  def self.fetch_story(id)
      
      if (!test?) || (test? && id!='2')
        resource_uri = URI.parse("http://www.pivotaltracker.com/services/v3/projects/#{$SETTINGS["project_id"]}/stories/#{id}")
        data = fetch_xml(resource_uri)
      else
          begin
            file = File.open("./test/xml/returned.xml")
            data = REXML::Document.new(file.read())
          ensure
            file.close()
          end
      end
      
      story_hash = { # Create a hash with out default data
        :ticket_id => id,
        :name => "Unknown story",
        :ticket_type => "unknown",
        :created => nil
      }
      if data==nil
        # Do nothing
      else
        if check_xml(data,id)
          parse_xml_story(data.root,story_hash)
        else
          puts "XML is invalid or does not match story"
          puts data
        end
      end
      
      db_story = create_story(story_hash,id)
      return db_story # Explicity for future reference 
    end
  
  def self.fetch_xml(uri,api_key)
    @retried = false
    
    if $SETTINGS['proxy']=='auto' && ENV['HTTP_PROXY']!=nil
      proxy = URI.parse(ENV['HTTP_PROXY'])
      proxy_class = Net::HTTP::Proxy(proxy.host,proxy.port)
    elsif $SETTINGS['proxy'] && ENV['HTTP_PROXY']!=nil
      proxy = URI.parse($SETTINGS['proxy'])
      proxy_class = Net::HTTP::Proxy(proxy.host,proxy.port)
    else
      proxy_class = Net::HTTP
    end
    
    begin
      response = proxy_class.start(uri.host, uri.port) do |http|
        http.get("#{uri.path}?#{uri.query}", {'X-TrackerToken' => api_key})
      end
      return REXML::Document.new(response.body)
    rescue
      if !@retried
        puts "Could not connect to API: retrying"
        @retried = true
        retry
      else
        puts "Could not connect to API: failed"
        return nil
      end
    end
    
  end
  
  def self.check_xml(data,id)
    if data.root == nil
      return {
        :status => false,
        :message => "The returned document contained no XML data.<br/>
        <strong>Response:</strong> #{data}"
      }
    elsif (id!='all' && data.root.name != 'story')
      return {
        :status => false,
        :message => "The returned document contained unexpected content.<br/>
        <strong>Expected XML root:</strong> story<br/>
        <strong>Obserbved XML root:</trong> #{data.root.name}"
      }
    elsif (id=='all' && data.root.name != 'stories')
      return {
        :status => false,
        :message => "The returned document contained unexpected content.<br/>
        <strong>Expected XML root:</strong> stories<br/>
        <strong>Obserbved XML root:</trong> #{data.root.name}"
      }
    elsif (id!='all' && (data.root.elements["id"] == nil || data.root.elements["id"].text != id))
      return {
        :status => false,
        :message => "The returned story is not the expected story.<br/>
        <strong>Expected ID:</strong> #{id}<br/>
        <strong>Obserbved ID:</trong> #{data.root.elements["id"].text}"
      }
    else
      return {
        :status=>true
      }
    end
  end
  
  def self.parse_xml_story(data,hash)
    begin
      hash[:ticket_id] = data.elements["id"].text if hash[:ticket_id]==nil
      hash[:name] = data.elements["name"].text
      hash[:created] = DateTime.parse(data.elements["created_at"].text)
      hash[:ticket_type] = data.elements["story_type"].text
      hash[:current_state] = data.elements["current_state"].text
      return true
    rescue
      return false
    end
  end
  
  def self.create_story(hash)
    begin
      db_story = Story.find_or_create_by_ticket_id_and_rejected_close(hash[:ticket_id],nil) 
      db_story.created = hash[:created]
      db_story.name = hash[:name]
      db_story.ticket_type = hash[:ticket_type]
      db_story.save
      if (hash[:current_state] != 'started')||(hash[:current_state] != 'rejected')
        db_story.update_state(hash[:current_state],hash[:created].to_s)
      elsif hash[:current_state] == 'rejected'
        deb_story.reject(hash[:created].to_s)
      end
      return db_story
    rescue # Just in case
      return false
    end
  end
  
  def self.paginate(messages,id,api,con_list,page,task)
    
    api_filter="?limit=#{$SETTINGS['page_size']}&offset=#{page*$SETTINGS['page_size']}&filter=includedone:true"

    if con_list !='all'
      api_filter << '%20id:' << con_list
    end
    uri = URI.parse("#{$SETTINGS['pt_api']}#{id}/stories#{api_filter}")
    data = fetch_xml(uri,api)
    
    if data == nil
      messages << {
        :id => 'bad_api',
        :classes => 'bad',
        :title => 'Error: Could not connect to API',
        :body => "The server could not connect to the Pivotal Tracker API. Check that your proxy settings are configured correctly, and that the Pivotal Tracker API is operational. The database has not been #{['populated','repaired','updated'][task]}."
      }
      return false
    end
    if data.to_s.include? 'Access denied.'
      messages << {
        :id => 'bad_api',
        :classes => 'bad',
        :title => 'Error: Access Denied',
        :body => "The server was forbidden from connecting to the Pivotal Tracker API. Check your API key and try again. The database has not been #{['populated','repaired','updated'][task]}."
      }
      return false
    end
    
    check = check_xml(data,'all')
    if !check[:status]
      messages << {
        :id => 'bad_xml',
        :classes => 'bad',
        :title => 'Error: Invalid XML returned on page #{page}',
        :body => "#{check[:message]}"
      }
      return false
    end
    
    # Check pagination
    position = page*$SETTINGS['page_size'] + $SETTINGS['page_size'] # Using expected values, as those returned by the API are unreliable (Ie. They are nill if we are using the defaults.)
    if position < data.root.attributes['total'].to_i
      new_data = paginate(messages,id,api,con_list,page+1,task)
      data.root << new_data.root.elements["story"] if new_data # If we have something, concatenate it
    end
    return data
  end
  
  def self.populate_database(messages,id,api,id_list)
    
    con_list ='all'
    task = 0
    if id_list !='all'
      con_list = id_list.join(',')
      task = 1
    end
    
    data = paginate(messages,id,api,con_list,0,task)
    
    # Parsing XML
      begin
        total = data.root.attributes['total']
        success = 0
        parse_error = 0
        create_error = 0
        data.elements.each('stories/story') do |story|
          # For each Story
          hash ={}
          parse_error = parse_error+1 unless parse_xml_story(story,hash)
          id_list.delete(hash[:ticket_id]) if id_list!='all'
          if create_story(hash)==false
            create_error = create_error + 1
          else
            success = success+1
          end
        end
        
      messages << report(success,total,parse_error,create_error,task,id_list)
      rescue
        messages << {
          :id => 'parsing_failure',
          :classes => 'bad',
          :title => 'Error: Problems parsing XML',
          :body => "The XML was not parsed correctly. Some stories may not have been #{['imported','repaired'][task]}.<br/>
          <strong>Imported:</strong> #{success} of #{total}. <strong>Parse Error:</strong> #{parse_error}. <strong>Create error:</strong> #{create_error}.<br/>
          Any stories not included in this count were unprocessed."
        }
      end
    # Done Parsing
    
  end
  
  
  def self.flag_deleted_items(messages,id,api,con_list)

    task = 2  
    data = paginate(messages,id,api,con_list,0,task)
    if con_list=='all'
      id_list = Story.total.map do |story|
        story.ticket_id().to_s
      end
    else
      id_list = con_list.split(',')
    end
    found = 0
    
    # Parsing XML

      begin
        total = data.root.attributes['total']
        scanned = id_list.length
        found_ids = []
        
        data.elements.each('stories/story') do |story|
          if story.elements["id"]
            found_ids << story.elements["id"].text
          end
        end   
      rescue
        messages << {
          :id => 'parsing_failure',
          :classes => 'bad',
          :title => 'Error: Problems parsing XML',
          :body => "The XML was not parsed correctly. The process has been aborted"
        }
        return false
      end
      begin
        deleted = []
        id_list.each do |id|
          if !found_ids.include?(id)
            Story.find_by_active_ticket_id(id).delete(Time.new.to_s)
            deleted << id
          end
        end
      rescue
              puts "<strong>Tested:</strong> #{scanned} <strong>Against:</strong> #{total} <strong>Flagged deleted:</strong> #{deleted.length}"
              bod = "A problem occured while deleting stories.<br/>"
              bod << "<strong>Tested:</strong> #{scanned} <strong>Against:</strong> #{total} <strong>Flagged deleted:</strong> #{deleted.length}"
              messages << {
                :id => 'deletion_failure',
                :classes => 'bad',
                :title => 'Error: Problems deleting stories',
                :body => bod
              }
              return false
            end
      messages << {
        :id => 'stories_deleted',
        :classes => 'good',
        :title => 'Stories sucesfully deleted',
        :body => "Of the #{scanned} stories tested, #{deleted.length} could not be found in the Pivitol Tracker database, and have been flagged as deleted.<br/>
        <strong>Flagged IDs:</strong> #{deleted.join(',')}"
      }
    
  end
  
  def self.report(success,total,parse_error,create_error,task,id_list)
    # Generate report   
    status = 0
    classes = ['good','bad']
    title = ["Stories sucesfully #{['imported','repaired'][task]}","Stories #{['imported','repaired'][task]} with errors"]
    message = "#{success} out of #{total} stories sucesfully #{['imported','repaired'][task]}. "
    if parse_error > 0
      status = 1
      message << "#{parse_error} stories suffered parser errors. Incomplete or malformed data was returned by Pivotal Tracker. "
    end
    if create_error > 0
      status = 1
      message << "#{create_error} stories could not be created. "
    end
    if (success + parse_error + create_error) < total.to_i
      status = 1
      message << "Caution! The total number of stories processed does not match that reported by the API."
    end
    if (id_list!='all' && id_list.length > 0)
      status = 1
      message << "#{id_list.length} stories could not be found in the Pivotal Tracker database and may have been deleted.<br/>
      <strong>Missing stories:</strong> #{id_list.join(',')}<br/>
      Use the 'remove stories' function to remove these stories."
    end
    return {
      :id => ['database_import','database_repair'][task],
      :classes => classes[status],
      :title => title[status],
      :body => message
    }
  end
  
  def self.incomming(xml)
    return nil if xml == '' # Drop empty posts
    data = REXML::Document.new(xml)
    begin
      return nil if data.root == nil
      
      if data.root.name == 'activity'  # Drop out if things don't look right
        data.elements.each('activity') do |activity|
          if activity.elements["project_id "].text == $SETTINGS['project_id'].to_s # Drop out if we have the wrong project
            parse_incomming(activity)
          end
        end

      elsif data.root.name == 'activities'
        data.elements.each('*/activity') do |activity|
          if activity.elements["project_id "].text == $SETTINGS['project_id'].to_s # Drop out if we have the wrong project
            parse_incomming(activity)
          end
        end
      end
      
    rescue
      puts "XML Parsing Failed: #{xml}"
      return nil
    end
    return nil
  end
  
  def self.parse_incomming(data)
    # begin
      event_type = data.elements["event_type"].text
      date = DateTime.parse(data.elements["occurred_at"].text)
      
      data.elements.each("stories/story") do |rec_story|
        # For each story: Should only be one
        ticket_id = rec_story.elements["id"].text
        db_story = Story.find_or_create_by_ticket_id_and_rejected_close(ticket_id,nil)
        if event_type =='story_create'
          db_story.name = rec_story.elements["name"].text
          db_story.created = date
          db_story.ticket_type = rec_story.elements["story_type"].text
          db_story.save
         elsif event_type == 'story_update'
           db_story.name = "Unknown story" if db_story.name == nil
           db_story.created = nil if db_story.created == nil
           db_story.ticket_type = 'unknown' if db_story.ticket_type == nil
           new_state = rec_story.elements["current_state"].text unless rec_story.elements["current_state"] == nil
           db_story.update_state(new_state,data.elements["occurred_at"].text)
         elsif event_type == 'story_delete'
           db_story.delete(data.elements["occurred_at"].text)
         end
       end
       
     # rescue
     #   puts "Parsing fails of XML block: #{data}"
     # end
   end
    
end