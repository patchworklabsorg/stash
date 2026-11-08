# frozen_string_literal: true

class SearchIndexGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path('templates', __dir__)

  def self.next_migration_number(_dirname)
    Time.now.utc.strftime('%Y%m%d%H%M%S')
  end

  def create_migration_file
    migration_template 'migration.rb.erb', "db/migrate/add_search_index_to_#{table_name}.rb"
  end

  private

  def table_name
    file_name.tableize
  end
end
