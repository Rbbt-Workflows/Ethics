module SinatraEthicsMisc
  def self.registered(app)
    app.post '/save_document' do
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

    app.post '/save_document' do
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

    # Simple frameworks list using Ethics::FRAMEWORKS (strings)
    app.get "/frameworks" do
      @frameworks = Ethics::FRAMEWORKS
      render_template('frameworks/index')
    end
  end
end
