# Agents.md

This file provides guidance to Agents when working with code in this repository.

## Overview

Ethics is a Ruby-based web application for evaluating ethical use cases against various ethical frameworks using LLM agents. Built on the Scout and Scout-AI frameworks, it provides a Sinatra web interface for managing ethical frameworks, corpus documents, prompts, and running evaluations.

## Technology Stack

- **Backend**: Ruby 3.1+, Sinatra web framework
- **Core Framework**: Scout workflow system with Scout-AI for LLM integration
- **Frontend**: Slim templates, TailwindCSS + DaisyUI, HTMX for dynamic interactions
- **Testing**: Ruby Test::Unit

## Essential Commands

### Running the Application

```bash
# Start the web server (via Rack)
rackup config.ru

# Or use the standard Scout workflow server command
# The app runs on port 9292 by default
```

### Frontend Development

```bash
# Build TailwindCSS (one-time)
npm run build:css

# Watch and rebuild CSS during development
npm run watch:css
```

### Testing

```bash
# Run all tests
ruby -Ilib:test test/test_helper.rb

# Run a specific test file
ruby -Ilib:test test/entity/test_corpus.rb
```

### Dependencies

```bash
# Install Ruby gems
bundle install

# Install Node dependencies for TailwindCSS
npm install
```

## Architecture

### Scout Workflow System

This application extends the Scout Workflow framework, which provides:
- **Task definitions**: Define computational tasks with typed inputs/outputs
- **Job management**: Asynchronous task execution with dependency tracking
- **Entity system**: Rich domain objects with properties and persistence
- **Path management**: Organized file system structure via `Scout.share`, `Scout.etc`

### Core Domain Entities

The application models five key domain entities (in `lib/entity/`):

1. **Framework** (`framework.rb`): Represents ethical frameworks (e.g., "Utilitarianism", "Care Ethics")
   - Stored in `share/corpora/` and `share/frameworks/`
   - Has multiple versions of documentation corpus
   - Properties: `versions`, `documents_for_version`, `corpus_dir`

2. **Corpus** (`corpus.rb`): A versioned collection of documents for a framework
   - Identified as `"Framework·version"` (dot separator)
   - Contains multiple documents in a directory structure
   - Properties: `documents`, `directory`, `add_document`

3. **Document** (`document.rb`): Individual files within a corpus
   - Identified as `"Framework·version·path"` (dot separators)
   - Properties: `content`, `save`, `file`

4. **UseCase** (`use_case.rb`): Scenarios to be ethically evaluated
   - Stored in `share/use_cases/`
   - Contains description text
   - Can generate evaluation jobs: `evaluate_job(framework, version, endpoint)`

5. **Prompt** (`prompt.rb`): Versioned prompt templates for LLM agents
   - Stored in `share/prompts/`
   - Identified as `"role·version"` (e.g., "evaluator·v1")
   - Roles include: evaluator, coordinator, generator, prepare

### Workflow Tasks

The main workflow is defined in `workflow.rb`:

1. **`evaluate`**: Core task that evaluates a use case using an ethical framework
   - Inputs: use_case (text), framework, framework_version, prompt_version, endpoint
   - Creates LLM agent with framework corpus as context
   - Returns evaluation results and saves chat history

2. **`prepare`**: Generates corpus documentation for a framework
   - Uses coordinator agent to determine needed files
   - Uses generator agent to create content for each file
   - Returns list of generated files

3. **`prepare_version`**: Links prepared corpus to a framework version
   - Depends on `prepare` task
   - Creates versioned corpus directory

4. **`run_suite`**: Batch evaluates across multiple frameworks/versions

### Web Application Structure

The Sinatra app (`lib/sinatra.rb`) is organized into modules:

- **`lib/sinatra/runs.rb`**: Job/run management endpoints
  - `/main/runs`: List and filter evaluation jobs
  - `/runs/info`: Job metadata display
  - `/runs/view`: Job result viewing
  - `/runs/clean`: Clean job files (DELETE)

- **`lib/sinatra/prompts.rb`**: Prompt management (likely)

- **`lib/sinatra/helpers.rb`**: View helpers
  - Markdown rendering via Kramdown (GFM)
  - CSRF token management
  - Job finding utilities: `find_job_by_param`, `jobs_for_evaluate`
  - Entity fragment rendering

- **Views**: Slim templates in `share/views/`
  - `main/`: Dashboard views (frameworks, runs, use_cases, prompts)
  - `entity/`: Entity-specific views (Framework, Corpus, Document, UseCase, Prompt, Evaluation)
  - `partial/`: Reusable fragments
  - Uses HTMX triggers for dynamic updates

### Entity Pattern

Entities use Scout's annotation system with a consistent pattern:
- Entities are strings with special separator `"·"` (middle dot, not period)
- `parts` property splits the identifier
- Properties are defined via `property :name do ... end`
- Persistence via `persist :property_name, :type`
- All entities have a `check` property that validates their backing resource

### Data Organization

```
share/
├── corpora/          # Versioned framework documents
│   ├── Utilitarianism/
│   │   └── v1/       # Version-specific documents
│   └── Care Ethics/
├── frameworks/       # Framework metadata
├── prompts/          # Versioned LLM prompts
│   ├── v1/
│   └── extended_prepare/
├── use_cases/        # Use case descriptions
└── views/            # Slim templates
```

## Common Development Patterns

### Creating an Evaluation Job

```ruby
framework = Framework.setup("Utilitarianism")
use_case = UseCase.setup("autonomous_vehicle_scenario")
job = Ethics.job(:evaluate,
  use_case: use_case.description,
  framework: framework,
  framework_version: "v1",
  prompt_version: "v1",
  endpoint: :openai
)
job.run
```

### Working with Entities

```ruby
# Framework operations
framework = Framework.setup("Care Ethics")
versions = framework.versions                    # List versions
corpus = framework.corpus("v1")                  # Get specific version
documents = framework.documents_for_version("v1") # List documents

# Corpus operations
corpus = Corpus.setup("Utilitarianism·v1")
docs = corpus.documents                          # Get all documents
corpus.add_document("new_doc.md", "content...")  # Add new document

# Document operations
doc = Document.setup("Utilitarianism·v1·intro.md")
content = doc.content                            # Read content
doc.save("updated content")                      # Update content
```

### Adding New Routes

When adding Sinatra routes, register your module in `lib/sinatra.rb`:

```ruby
class EthicsApp < Sinatra::Base
  register YourNewModule
  # ...
end
```

Routes should set appropriate HX-Trigger headers for HTMX (see `after` block in `sinatra.rb`).

## Key Dependencies and Conventions

- **Scout Paths**: Use `Scout.share`, `Scout.etc` for accessing shared resources
- **Open utility**: Scout's `Open` module for file operations (read/write/mkdir)
- **LLM Agents**: Created via `LLM.agent endpoint: :openai`
  - Set system prompt: `agent.system "..."`
  - Add directories: `agent.directory path`
  - Chat: `agent.chat` or `agent.ask`
- **Entity separator**: Always use `"·"` (middle dot, U+00B7) not `"."` (period)
- **Workflow endpoints**: Defined in `Scout.etc.AI.glob('*')` (e.g., openai, deep, nano)

## Testing Patterns

Tests use standard Ruby Test::Unit. The test helper sets up load paths:

```ruby
require 'test/unit'
require_relative '../lib/your_file'

class TestYourClass < Test::Unit::TestCase
  def test_something
    # ...
  end
end
```

## Configuration

- `config.ru`: Rack configuration, sets up OmniAuth for authentication
- `Gemfile`: Ruby dependencies (Sinatra, Haml, Kramdown, Diffy, Puma)
- `package.json`: Node dependencies for TailwindCSS build pipeline
- `tailwind.config.js`: TailwindCSS configuration with DaisyUI plugin

## Git Workflow

Current branch: `main` (also the default branch for PRs)

Recent commits show work on:
- Prompt versioning system
- Layout improvements
- Chat interface refinements
