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
require 'scout/sinatra/render'
require 'scout/sinatra/entity'

require_relative "entity/framework"
require_relative "entity/corpus"
require_relative "entity/document"
require_relative "entity/use_case"
require_relative "entity/evaluation"

Workflow.require_workflow "Ethics"

class EthicsApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end
  
  before do
    content_type "text/html; charset=utf-8"
    headers "X-Frame-Options" => "DENY"
  end


  post '/save_document' do
    document = consume_parameter(:document)
    content = consume_parameter(:content)

    Document.setup(document).save(content)

    case _format
    when :html
      redirect entity_url(document.corpus)
    when :json
      json_halt 200, {}
    end
  end

  # Dashboard (placeholder)
  get "/" do
    redirect "/main/frameworks"
  end

  # Simple frameworks list using Ethics::FRAMEWORKS (strings)
  get "/frameworks" do
    @frameworks = Ethics::FRAMEWORKS
    render_template('frameworks/index')
  end

  not_found do
    haml "%div.p-8.text-center.text-slate-500 404 Not Found"
  end

  error do
    err = env["sinatra.error"]
    haml "%div.p-8.text-center.text-rose-600 Error: #{h err.message}"
  end

  get '/main/runs' do
    authorize_manage_runs!

    # Load jobs
    jobs = jobs_for_evaluate

    # Filtering
    status_filter = params[:status].to_s.strip.downcase if params[:status]
    framework_filter = params[:framework].to_s.strip if params[:framework] && params[:framework].to_s.strip != ""
    # Simple text search in use_case input
    q = params[:q].to_s.strip if params[:q]

    jobs = jobs.select do |j|
      inputs = (j.respond_to?(:inputs) && j.inputs) ? (begin; IndiferentHash.setup(j.inputs.dup) rescue IndiferentHash.setup(j.inputs) rescue {}; end) : {}
      ok = true
      if status_filter && !status_filter.empty?
        sts = (j.respond_to?(:status) ? j.status.to_s.downcase : (j.respond_to?(:state) ? j.state.to_s.downcase : ""))
        ok &&= (sts == status_filter)
      end
      if framework_filter && !framework_filter.empty?
        fw = inputs[:framework] || inputs['framework'] || ""
        ok &&= (fw.to_s == framework_filter)
      end
      if q && !q.empty?
        uc = inputs[:use_case] || inputs['use_case'] || ""
        ok &&= (uc.to_s.downcase.include?(q.downcase) || (j.respond_to?(:path) && j.path.to_s.downcase.include?(q.downcase)))
      end
      ok
    end

    # Sorting (most recent first) by start_time / mtime / created_at if present
    jobs = jobs.sort_by { |j|
      t = (j.respond_to?(:start_time) && j.start_time) ||
          (j.respond_to?(:mtime) && j.mtime) ||
          (j.respond_to?(:created_at) && j.created_at) rescue nil
      t ? -t.to_i : 0
    }

    # Pagination
    per_page = (params[:per_page] || 25).to_i
    page = (params[:page] || 1).to_i
    page = 1 if page < 1
    total = jobs.length
    total_pages = (total.to_f / per_page).ceil
    jobs = jobs.slice((page - 1) * per_page, per_page) || []

    @jobs = jobs
    @jobs_total = total
    @page = page
    @per_page = per_page
    @total_pages = total_pages
    @filters = { status: status_filter, framework: framework_filter, q: q }

    render_template('main/runs')
  end

  # Fetch job metadata (side pane)
  get '/runs/info' do
    authorize_manage_runs!
    job_param = params[:job] || params[:path]
    job = find_job_by_param(job_param)
    halt 404, "Job not found" unless job
    @job = job
    render_template('main/run_info')
  end

  # View job — either show final result (if done) or the wait fragment
  get '/runs/view' do
    authorize_manage_runs!
    job_param = params[:job] || params[:path]
    job = find_job_by_param(job_param)
    halt 404, "Job not found" unless job

    # If job finished and has content (job.load), render it; otherwise show wait fragment
    if job.respond_to?(:status) && job.status.to_s == 'done'
      render_template('main/run_info', job: job)
    else
      # Job still running/queued -> show wait fragment that auto-polls
      render_template('wait')
    end
  end

  # Clean produced files for job (DELETE)
  delete '/runs/clean' do
    authorize_manage_runs!
    job_param = params[:job] || params[:path]
    job = find_job_by_param(job_param)
    halt 404, "Job not found" unless job

    cleaned = false
    errors = []
    begin
      if job.respond_to?(:files_dir) && job.files_dir && Open.exists?(job.files_dir)
        Open.rm_rf job.files_dir
        cleaned = true
      else
        # If the job exposes a clean method, try it
        if job.respond_to?(:clean)
          job.clean
          cleaned = true
        end
      end
    rescue => e
      errors << e.message
    end

    if errors.any?
      status 500
      body({ ok: false, errors: errors }.to_json)
    else
      status 204
    end
  end

  register SinatraScoutRender
  register SinatraScoutEntity

  helpers do
    def h(s)
      Rack::Utils.escape_html(s.to_s)
    end

    def markdown(text)
      return "" if text.to_s.strip.empty?
      Kramdown::Document.new(text.to_s, input: "GFM").to_html
    end

    # Return a Framework entity instance (strings are entity-annotated via Framework.setup)
    def framework_entity(name)
      Framework.setup(name)
    end

    def csrf_token
      session[:csrf] ||= SecureRandom.hex(16)
    end

    def nav_active?(path)
      request.path_info == path
    end

    # Utility: ensure filename safe-ish (for doc file creation)
    def safe_filename(str)
      base = str.to_s.strip
      base = "untitled" if base.empty?
      base = base.downcase
      base = base.gsub(/[^\p{Alnum}\-_\.\s]/u, '-') # keep alnum, dash, underscore, dot, space
      base = base.strip.gsub(/\s+/, '-')
      base = base.gsub(/-+/, '-')
      base += ".md" unless base =~ /\.(md|markdown|txt)\z/i
      base
    end

    # Utility: encode/decode doc names in URLs
    def enc(s) URI.encode_www_form_component(s.to_s) end
    def dec(s) URI.decode_www_form_component(s.to_s) end

    def ajax?
      ! request.env['HTTP_HX_TARGET'].nil?
    end

    #
    # Helpers for run management
    #
    def jobs_for_evaluate
      return [] unless defined?(Ethics) && Ethics.respond_to?(:task_jobs)
      Array(Ethics.task_jobs(:evaluate))
    end

    # Find a job by its path or identifier; accepts either the job object or a string path
    def find_job_by_param(job_param)
      return job_param if job_param && job_param.respond_to?(:path)
      return nil unless job_param
      # If Ethics provides a helper to get a job by path, prefer it
      if defined?(Ethics) && Ethics.respond_to?(:task_job)
        begin
          j = Ethics.task_job(job_param) rescue nil
          return j if j
        rescue
        end
      end

      # Fallback: search through evaluate jobs by matching path.to_s
      jobs_for_evaluate.find do |j|
        jpath = (j.respond_to?(:path) ? j.path.to_s : j.to_s)
        jpath == job_param.to_s || File.basename(jpath) == job_param.to_s
      end
    end

    # Very small authorization helper: replace/extend as needed.
    def authorize_manage_runs!
      # If your app has a current user mechanism, require it here.
      # For now allow by default, but if `user` exists and must be present require it.
      return true
      return true unless respond_to?(:user)
      halt 401, "Login required" unless user
      true
    end
  end
end
