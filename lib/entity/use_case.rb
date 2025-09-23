require 'scout'
module UseCase
  extend Entity

  @use_case_dir = Scout.share.use_cases.find(:lib)
  singleton_class.attr_accessor :use_case_dir

  property :description do
    UseCase.use_case_dir[self].read
  end

  # Save new description text
  def save(content)
    Open.mkfiledir UseCase.use_case_dir[self]
    Open.write UseCase.use_case_dir[self], content.to_s
    true
  end

  # Remove the backing file
  def delete
    Open.rm_rf UseCase.use_case_dir[self]
    true
  end
end
