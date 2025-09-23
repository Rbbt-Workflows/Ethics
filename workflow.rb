require 'scout'
require 'scout-ai'

Misc.add_libdir if __FILE__ == $0
require 'entity/framework'

#require 'rbbt/sources/MODULE'

module Ethics
  extend Workflow

  FRAMEWORKS = Framework.setup Scout.share.frameworks.glob("*").map{ Framework.setup(it.basename) }
  ENDPOINTS = Scout.etc.AI.glob('*').collect{|f| f.basename }

  input :use_case, :text, 'Description of use case to evaluate', nil, required:true 
  input :framework, :select, 'Framework to apply', nil, select_options: FRAMEWORKS
  input :version, :select, 'Framework version to use', 'active'
  input :endpoint, :select, 'Endpoint to user for inference', :openai, select_options: ENDPOINTS
  task :evaluate => :text do |use_case,framework,endpoint|
    framework = Framework.setup(framework)
    agent = LLM.agent endpoint: endpoint
    agent.import Scout.share.prompts.evaluator.find

    version = framework.version if version.nil? || version.to_s == 'active'

    agent.directory framework.corpus_for_version(version)

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

  input :prompt, :text, 'Prompt to use to generate the documentation', nil, required: true
  input :framework, :select, 'Framework to apply', nil, select_options: FRAMEWORKS
  input :endpoint, :select, 'Endpoint to user for inference', :openai, select_options: ENDPOINTS
  task :prepare => :array do |prompt,framework,endpoint|
    coordinator = LLM.agent
    coordinator.import Scout.share.prompts.coordinator.find
    coordinator.user <<-EOF
The user wants to create documentation for the framework #{framework},
following these instructions:

<instructions>
#{prompt}
<instructions/>

Please determine the list of files that need to be created
    EOF

    generator = LLM.agent endpoint: endpoint
    generator.start_chat.import Scout.share.prompts.generator.find
    generator.start_chat.user <<-EOF
The user wants to create documentation for the framework #{framework},
following these instructions:

<instructions>
#{prompt}
<instructions/>
    EOF
    dictionary = coordinator.json
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
end

#require 'MODULE/tasks/basic.rb'

#require 'rbbt/knowledge_base/MODULE'
#require 'rbbt/entity/MODULE'

iif Ethics.task_jobs :evaluate
