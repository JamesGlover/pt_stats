module PtApi
  require 'rubygems'
  require 'rexml/document'
  require 'net/http'
  require 'uri'
  

  def self.fetch_story(id)
    resource_uri = URI.parse("http://www.pivotaltracker.com/services/v3/projects/#{$PROJECT_ID}/stories/#{id}")
    proxy = URI.parse(ENV['HTTP_PROXY'])
    proxy_class = Net::HTTP::Proxy(proxy.host,proxy.port)
    if (!test?) || (test? && id!='2')
      response = proxy_class.start(resource_uri.host, resource_uri.port) do |http|
        http.get(resource_uri.path, {'X-TrackerToken' => $API_TOKEN})
      end
      puts response.body
      data = REXML::Document.new(response.body)
    else
        file = File.open("./test/xml/returned.xml")
        data = REXML::Document.new(file.read())
        file.close()
    end

    db_story=data.elements.each("story") do |rec_story|
      ticket_id = rec_story.elements["id"].text
      date = DateTime.parse(rec_story.elements["created_at"].text)
      
      begin
        db_story = Story.create!(
        :ticket_id => ticket_id,
        :name => rec_story.elements["name"].text,
        :created => date,
        :ticket_type => rec_story.elements["story_type"].text
        )
      rescue # Just in case
        db_story = Story.find_by_ticket_id(id)
        db_story.created = date
        db_story.save
      end
      return db_story
    end
    
    return db_story
  end
end