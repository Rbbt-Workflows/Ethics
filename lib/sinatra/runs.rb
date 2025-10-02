module SinatraEthicsRuns
  def self.registered(app)
    app.get '/main/runs' do
      authorize_manage_runs!

      # Load jobs
      jobs = jobs_for_evaluate

      # Filtering
      status_filter = params[:status].to_s.strip.downcase if params[:status]
      framework_filter = params[:framework].to_s.strip if params[:framework] && params[:framework].to_s.strip != ""
      # Simple text search in use_case input
      q = params[:q].to_s.strip if params[:q]

      jobs = jobs.select do |j|
        inputs = if (j.respond_to?(:inputs) && j.inputs) 
                   begin
                     IndiferentHash.setup(j.inputs.dup) 
                   rescue 
                     IndiferentHash.setup(j.inputs) rescue {}
                   end 
                 else 
                   {}
                 end
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
    app.get '/runs/info' do
      authorize_manage_runs!
      job_param = params[:job] || params[:path]
      job = find_job_by_param(job_param)
      halt 404, "Job not found" unless job
      @job = job
      render_template('main/run_info')
    end

    # View job — either show final result (if done) or the wait fragment
    app.get '/runs/view' do
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
    app.delete '/runs/clean' do
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
  end
end
