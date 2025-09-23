require 'scout'
module Document
  extend Entity

  annotation :version

  property :parts do
    self.split("·")
  end

  property :framework do
    parts.first
  end

  property :version do
    parts[1]
  end

  property :path do
    parts[2]
  end

  property :corpus do
    Corpus.setup([framework, version] * "·")
  end

  property :content do
    corpus.directory[path].read
  end
  
  property :save do |content|
    corpus.save path, content
  end
end

