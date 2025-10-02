module SinatraEthicsHelpers
  def self.registered(app)
    app.helpers do
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

      def entity_fragment(entity, type = :entity, other = nil, filter = '', options = {})
        render_partial('partial/entity_fragment', entity: entity, type: type, other: other, filter: filter, options: options)
      end
    end

    app.not_found do
      haml "%div.p-8.text-center.text-slate-500 404 Not Found"
    end
  end
end
