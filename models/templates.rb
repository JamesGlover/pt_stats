class Template
  module TemplateMethods
    def initialize(template)
      @template = "./views/elements/#{template}.erb"
    end
  
    def fill(source_binding)
      File.open(@template) do |file|
        ERB.new(file.read)
      end.result(source_binding)
    end
  end
  
  include TemplateMethods

end
