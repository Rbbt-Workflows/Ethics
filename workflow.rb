require 'scout'
require 'scout-ai'

Misc.add_libdir if __FILE__ == $0
require 'entity/framework'

#require 'rbbt/sources/MODULE'

module Ethics
  extend Workflow

  FRAMEWORKS = Framework.setup Scout.share.corpora.glob_names("*")
  ENDPOINTS = Scout.etc.AI.glob('*').collect{|f| f.basename }

  input :use_case, :text, 'Description of use case to evaluate', nil, required:true 
  input :framework, :select, 'Framework to apply', nil, select_options: FRAMEWORKS
  input :framework_version, :select, 'Framework version to use', nil, required: true
  input :prompt_version, :select, 'Prompt version to use', nil, required: true
  input :endpoint, :select, 'Endpoint to user for inference', :openai, select_options: ENDPOINTS
  task :evaluate => :text do |use_case,framework,framework_version,prompt_version,endpoint|
    framework = Framework.setup(framework)

    agent = LLM.agent endpoint: endpoint
    
    agent.system Scout.share.prompts[prompt_version].evaluator.find

    agent.directory framework.corpus_dir(framework_version)

    agent.user <<-EOF
Please evaluate the following use case using the Ethical framework #{framework}.
Use the documents you have been provided for this evaluation

Use case:

#{use_case}
    EOF

    res = agent.chat

    agent.save file('chat')

    res
  end

  input :framework, :select, 'Framework to apply', nil, select_options: FRAMEWORKS
  input :prompt_version, :select, 'Prompt version to use', nil, required: true
  input :endpoint, :select, 'Endpoint to user for inference', :openai, select_options: ENDPOINTS
  task :prepare => :array do |framework,prompt_version,endpoint|

    coordinator = LLM.agent
    coordinator.system Scout.share.prompts[prompt_version].coordinator.find
    coordinator.user <<-EOF
The user wants to create documentation for the framework #{framework},
following these instructions:

<instructions>
#{Scout.share.prompts[prompt_version].prepare.read}
<instructions/>

Please determine the list of files that need to be created
    EOF

    dictionary = coordinator.json

    generator = LLM.agent endpoint: endpoint
    generator.start_chat.system Scout.share.prompts[prompt_version].generator.find
    generator.start_chat.user <<-EOF
The user wants to create documentation for the framework #{framework},
following these instructions:

<instructions>
#{prompt}
<instructions/>
    EOF
    generator.option :previous_response_id, coordinator.get_previous_response_id

    dictionary.each do |file, description|
      generator.start unless %w(openai deep nano).include? endpoint
      generator.user <<-EOF
Please generate the documentation for this file: #{file}, part of the
corpus of framework #{framework}

The content description of the file is:

#{description}
      EOF

      content = generator.chat
      Open.write(file(file), content)
    end

    files
  end

  dep :prepare
  input :version, :string, 'Target version', nil, required: true
  task :prepare_version => :array do |version|
    prepare = step(:prepare)
    framework = Framework.setup(prepare.inputs[:framework])

    Open.link prepare.files_dir, framework.corpus_dir(version)
    prepare.files_dir.glob_names("*")
  end

  input :framework_versions, :json, "Dictionary with framework versions", nil, required: true
  dep :evaluate, framework: :placeholder, framework_versions: :placeholder do |jobname, options|
    framework_versions = options[:framework_versions]
    framework_versions = JSON.parse(framework_version) if String === framework_versions
    Ethics::FRAMEWORKS.collect do |framework| 
      version = framework_versions[framework]
      options.merge(framework: framework, framework_version: version)
    end
  end
  extension :md
  task :run_suite => :binary do
  end

end

#require 'MODULE/tasks/basic.rb'

#require 'rbbt/knowledge_base/MODULE'
#require 'rbbt/entity/MODULE'
