require 'scout'

module Framework
  extend Entity
  
  def self.corpora_base_dir
    Scout.share.corpora.find
  end

  property :corpora_dir do
    Corpus.corpora_dir[self]
  end

  property :corpus_dir do |version|
    corpora_dir[version]
  end

  property :corpus do |version|
    Corpus.setup([self, version]*"·")
  end

  property :versions do
    corpora_dir.glob_names("*")
  end

  property :documents_for_version do |version|
    corpus(version).documents
  end

  property :description do
    agent = LLM.agent endpoint: :nano 
    agent.ask <<-EOF
Provide a one-paragraph description of the framework #{self}
    EOF
  end
  persist :description, :string

  property :one_liner do
    agent = LLM.agent endpoint: :nano 
    agent.ask <<-EOF
Provide a one-line description of the framework #{self}
    EOF
  end
  persist :one_liner, :string

  property :new_version do |target|
    target_dir = corpus_dir(target)
    raise "Target exists #{target}" if target_dir.exists?
    Open.mkdir target_dir
  end

  property :delete_version do |target|
    target_dir = corpus_dir(target)
    raise "Target does not exists #{target}" unless target_dir.exists?
    Open.rm_rf target_dir
  end


  property :clone_version do |source,target|
    source_dir = corpus_dir(source)
    target_dir = corpus_dir(target)

    raise "Target exists #{target}" if target_dir.exists?

    Open.link source_dir, target_dir
  end

  property :prepare_version_job do |target,prompt,endpoint|
    target_dir = corpus_dir(target)
    raise "Target exists #{target}" if target_dir.exists?
    Ethics.job(:prepare_version, prompt: prompt, framework: self, endpoint: endpoint, version: target)
  end

  property :check do
    corpora_dir
  end
end
