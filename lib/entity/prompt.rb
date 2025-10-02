module Prompt
  extend Entity

  property :content do
    Scout.share.prompts[self].read
  end
end
