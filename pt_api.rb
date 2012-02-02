module PtApi
  require 'rubygems'
  require 'rexml/document'
  require 'net/http'
  require 'uri'
  

  def self.fetch_story(id)
    
    if (!test?) || (test? && id!='2')
      resource_uri = URI.parse("http://www.pivotaltracker.com/services/v3/projects/#{$PROJECT_ID}/stories/#{id}")
      proxy = URI.parse(ENV['HTTP_PROXY'])
      proxy_class = Net::HTTP::Proxy(proxy.host,proxy.port)
      data = fetch_xml(resource_uri,proxy_class)
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
      :created => DateTime.parse("01/01/2000")
    }
    
    if data==nil
      # Do nothing
    else
      if check_xml(data,id)
        parse_xml(data,story_hash)
      else
        puts "XML is invalid or does not match story"
      end
    end
    
    db_story = create_story(story_hash,id)
    return db_story # Explicity for future reference 
  end
  
  def self.fetch_xml(uri,proxy)
    @retried = false
    begin
      response = proxy.start(uri.host, uri.port) do |http|
        http.get(uri.path, {'X-TrackerToken' => $API_TOKEN})
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
    if data.root == nil || data.root.name != 'story' || data.root.elements["id"] == nil || data.root.elements["id"].text != id
      return false # The XML is invalid
    else
      return true
    end
  end
  
  def self.parse_xml(data,hash)
    begin
      hash[:name] = data.root.elements["name"].text
      hash[:created] = DateTime.parse(data.root.elements["created_at"].text)
      hash[:ticket_type] = data.root.elements["story_type"].text
    rescue
      puts "XML passed validation but could not be parsed: Check API changes"
    end
  end
  
  def self.create_story(hash,id)
    begin
      db_story = Story.create!(
        :ticket_id => hash[:ticket_id],
        :name => hash[:name],
        :created => hash[:created],
        :ticket_type => hash[:ticket_type]
      )
    rescue # Just in case
      db_story = Story.find_by_ticket_id(id)
      if db_story != nil #Ie. The story has been create in the meantime
       db_story.created = hash[:created] if db_story.created == nil
       db_story.name = hash[:name] if db_story.name == nil
       db_story.ticket_type = hash[:ticket_type] if db_story.ticket_type == nil
       db_story.save
     end
    end
    return db_story
  end
    
end