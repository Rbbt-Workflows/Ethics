module SinatraEthicsRuns
  def self.registered(app)

    app.post '/prompt/clone_version' do
      source = consume_parameter(:source)
      version = consume_parameter(:version)

      raise "No source version given" if source.nil? || source.empty?
      raise "No target version given" if version.nil? || version.empty?

      source_dir = Prompt.prompts_dir[source]
      target_dir = Prompt.prompts_dir[version]
      raise "Source version does not exist" unless source_dir.exists?
      raise "Target version exist" if target_dir.exists?
      raise "Target version invalid" unless target_dir.relative_to Prompt.prompts_dir

      Open.cp source_dir, target_dir

      headers["HX-Refresh"] = true
      halt 200, target_dir
    end

    app.delete '/prompt/delete_version' do
      version = consume_parameter(:version)

      raise "No version given" if version.nil? || version.empty?
      target_dir = Prompt.prompts_dir[version]
      raise "Version does not exist" unless target_dir.exists?

      Open.rm_rf target_dir

      headers["HX-Refresh"] = true
      halt 200, target_dir
    end

  end
end
