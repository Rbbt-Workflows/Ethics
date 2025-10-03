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

  property :content do
    Scout.share.prompts[version][role].read
  end

  property :save do |content|
    Scout.share.prompts[version][role].write content
  end
end
