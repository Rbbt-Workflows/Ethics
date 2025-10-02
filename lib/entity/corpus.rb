require 'scout'
module Corpus
  extend Entity

  @corpora_dir = Scout.share.corpora.find(:lib)
  singleton_class.attr_accessor :corpora_dir

  property :parts do
    self.split("·")
  end

  property :framework do
    parts.first
  end

  property :version do
    parts[1]
  end

  property :directory do
    Corpus.corpora_dir[framework][version]
  end

  property :documents do
    directory.glob("**/**").
      reject{|f| f.directory?}.
      collect{|f| f.relative_to directory }
  end

  property :document do |document|
    Document.setup([self, document] * "·")
  end

  property :add_document do |name,content|
    document(name).save content
  end

  def check_filename(filename)
    filename = filename.find if Path === filename
    raise "Not relative" unless Misc.path_relative_to(File.expand_path(directory), filename)
  end

  def save(file, content)
    check_filename(directory[file])
    Open.write directory[file], content
  end

  def delete(file)
    check_filename(directory[file])
    Open.rm_rf directory[file]
  end

  property :check do
    directory
  end
end
