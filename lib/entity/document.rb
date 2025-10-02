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

  property :file do
    corpus.directory[path]
  end

  property :content do
    file.read
  end
  
  property :save do |content|
    corpus.save path, content
  end

  property :check do
    file
  end
end

