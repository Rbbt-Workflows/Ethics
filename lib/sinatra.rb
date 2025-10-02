require "sinatra/base"
require "sinatra/reloader"
require "haml"
require "json"
require "kramdown"
require "securerandom"
require "time"
require "fileutils"
require "cgi"
require "uri"

require 'scout'          # to use Scout paths, Open, Path
require 'scout/sinatra/base'
require 'scout/sinatra/entity'
require 'scout/sinatra/workflow'

require_relative "entity/framework"
require_relative "entity/corpus"
require_relative "entity/document"
require_relative "entity/use_case"
require_relative "entity/prompt"

require_relative 'sinatra/runs'
require_relative 'sinatra/helpers'

Workflow.require_workflow "Ethics"

class EthicsApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end
  
  before do
    content_type "text/html; charset=utf-8"
    headers "X-Frame-Options" => "DENY"
  end

  # Dashboard (placeholder)
  get "/" do
    redirect "/main/frameworks"
  end

  after do
    triggers = []

    status = case response.status
             when 200
               ['done', 'complete']
             when 500
               ['error', 'complete']
             when 202
               ['running']
             else
               []
             end
    
    if entity_type
      entity = (splat*"/").gsub(/\s/,'_')
      triggers << 'entity' 
      triggers << entity_type
      triggers << entity 
      triggers << [entity_type, entity]*'_'
    end

    if entity_property
      triggers << 'entity_property' 
      triggers << [entity_type, entity_property]*'_'
      triggers << [entity, entity_property]*'_'
      triggers << [entity_type, entity, entity_property]*'_'
      triggers << entity_property
    end

    if entity_action
      triggers << 'entity_action' 
      triggers << [entity_type, entity_action]*'_'
      triggers << [entity, entity_action]*'_'
      triggers << [entity_type, entity, entity_action]*'_'
      triggers << entity_action
    end

    if task_name
      triggers << 'task' 
      triggers << task_name
      triggers << [workflow, task_name]*"_"
    end

    triggers += triggers.collect{|t| status.collect{|s| [t, s]*"_" }}.flatten

    triggers << status

    headers['HX-Trigger'] = triggers * ", "
  end

  register SinatraScoutBase
  register SinatraEthicsRuns
  register SinatraEthicsHelpers
  register SinatraScoutEntity
  register SinatraScoutWorkflow

  add_workflow Ethics
end
