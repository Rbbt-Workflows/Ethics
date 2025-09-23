require 'scout'

module Framework
  extend Entity

  property :corpus_base_dir do
    Scout.share.frameworks.find
  end

  property :corpora_base_dir do
    Scout.share.corpora.find
  end

  property :corpus do
    corpus_base_dir[self]
  end

  property :corpora do
    corpora_base_dir[self]
  end

  property :corpus_for_version do |version|
    corpora[version]
  end

  property :version do
    File.basename(corpus.realpath)
  end

  property :versions do
    corpora.glob_names('*')
  end

  property :documents_for_version do |version=nil|
    version = self.version
    corpus_dir = corpus_for_version(version)
    corpus_dir.glob("**/**").
      reject{|p| p.directory? }.
      collect{|p| p.relative_to corpus_dir }
  end
  
  property :set_active do |version|
    Open.rm corpus
    Open.ln_s corpus_for_version(version), corpus_base_dir[self]
  end

  property :description do
    agent = LLM.agent endpoint: :nano 
    agent.directory corpus
    agent.ask <<-EOF
Provide a one-paragraph description of the framework #{self}
    EOF
  end
  persist :description, :string

  property :one_liner do
    agent = LLM.agent endpoint: :nano 
    agent.directory corpus
    agent.ask <<-EOF
Provide a one-line description of the framework #{self}
    EOF
  end
  persist :one_liner, :string

end
