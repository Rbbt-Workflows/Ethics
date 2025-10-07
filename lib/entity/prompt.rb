module Prompt
  extend Entity

  @prompts_dir = Scout.share.prompts.find(:lib)
  singleton_class.attr_accessor :prompts_dir

  def self.versions
    @prompts_dir.glob_names("*")
  end

  property :parts do
    self.split("·")
  end

  property :role do
    parts.first
  end

  property :version do
    parts[1]
  end

  property :file do
    Scout.share.prompts[version][role]
  end

  property :content do
    file.read
  end

  property :save do |content|
    file.write content
  end

  property :check do
    file
  end
end
