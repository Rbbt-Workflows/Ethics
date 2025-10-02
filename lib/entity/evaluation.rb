require 'scout'
module Evaluation
  extend Entity

  property :parts do
    self.split("·")
  end

  property :framework do
    parts.first
  end

  property :version do
    parts[1]
  end

  property :use_case do
    UseCase.setup(parts[2])
  end

  property :endpoint do
    parts[3] 
  end

  property :job do
    Ethics.job(:evaluate, use_case: use_case.description, framework: framework, endpoint: endpoint, version: version)
  end
end
