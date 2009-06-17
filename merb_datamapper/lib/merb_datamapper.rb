if defined?(Merb::Plugins)
  dependency 'dm-core'
  require 'merb-actionorm'

  require File.dirname(__FILE__) / "merb" / "orms" / "data_mapper" / "connection"
  require File.dirname(__FILE__) / "merb" / "session" / "data_mapper_session"
  Merb::Plugins.add_rakefiles "merb_datamapper" / "merbtasks"
  ActionORM.use :driver => :compliant, :for => DataMapper::Resource

  # conditionally assign things, so as not to override previously set options.
  # This is most relevent for :use_repository_block, which is used later in this file.
  unless Merb::Plugins.config[:merb_datamapper].has_key?(:use_repository_block)
    Merb::Plugins.config[:merb_datamapper][:use_repository_block] = true
  end

  unless Merb::Plugins.config[:merb_datamapper].has_key?(:session_storage_name)
    Merb::Plugins.config[:merb_datamapper][:session_storage_name] = 'sessions'
  end

  unless Merb::Plugins.config[:merb_datamapper].has_key?(:session_repository_name)
    Merb::Plugins.config[:merb_datamapper][:session_repository_name] = :default
  end

  module DataMapper
    module Resource

      # actionorm compliance
      alias new_record? new?

    end
  end

  class Merb::Orms::DataMapper::Connect < Merb::BootLoader
    after BeforeAppLoads

    def self.run
      Merb.logger.verbose! "Merb::Orms::DataMapper::Connect block."

      # check for the presence of database.yml
      if File.file?(Merb.dir_for(:config) / "database.yml")
        # if we have it, connect
        Merb::Orms::DataMapper.connect
      else
        # assume we'll be told at some point
        Merb.logger.info "No database.yml file found in #{Merb.dir_for(:config)}, assuming database connection(s) established in the environment file in #{Merb.dir_for(:config)}/environments"
      end

      # if we use a datamapper session store, require it.
      Merb.logger.verbose! "Checking if we need to use DataMapper sessions"
      if Merb::Config.session_stores.include?(:datamapper)
        Merb.logger.verbose! "Using DataMapper sessions"
        require File.dirname(__FILE__) / "merb" / "session" / "data_mapper_session"
      end

      # take advantage of the fact #id returns the key of the model, unless #id is a property
      Merb::Router.root_behavior = Merb::Router.root_behavior.identify(DataMapper::Resource => :id)

      Merb.logger.verbose! "Merb::Orms::DataMapper::Connect complete"
    end
  end

  if Merb::Plugins.config[:merb_datamapper][:use_repository_block]
    # wrap action in repository block to enable identity map
    class Application < Merb::Controller
      override! :_call_action
      def _call_action(*)
        DataMapper.repository do |r|
          Merb.logger.debug "In repository block #{r.name}"
          super
        end
      end
    end
  end

  generators = File.join(File.dirname(__FILE__), 'generators')
  Merb.add_generators generators / 'data_mapper_model'
  Merb.add_generators generators / 'data_mapper_resource_controller'
  Merb.add_generators generators / 'data_mapper_migration'
  
end
