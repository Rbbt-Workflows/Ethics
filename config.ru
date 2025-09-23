# frozen_string_literal: true
require 'scout'
require_relative "./lib/sinatra"
require 'scout/sinatra/auth'

EthicsApp.register SinatraScoutEntity
EthicsApp.register SinatraScoutAuth

ScoutRender.prepend_path :ethics, "/Users/mvazque2/git/workflows/Ethics/"
OmniAuth.config.silence_get_warning = true
OmniAuth.config.allowed_request_methods = %i[get]
run EthicsApp
