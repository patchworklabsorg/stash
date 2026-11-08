# The first schema: the stash schema itself, Active Storage's tables and Stash's own tables.
# GoodJob's tables come in the next migration.
class CreateStash < ActiveRecord::Migration[8.1]
  def change
    # Locally the schema does not exist yet. When deployed the infra module creates it, and the
    # app's role owns it but has no CREATE right on the database. Postgres checks that right
    # before it looks at IF NOT EXISTS, so only create the schema when it is missing. Either way,
    # every table below lands in "stash" (schema_search_path).
    # safety_assured: creating a schema that does not exist locks nothing.
    reversible do |dir|
      dir.up do
        exists = select_value("SELECT 1 FROM pg_namespace WHERE nspname = 'stash'")
        safety_assured { execute "CREATE SCHEMA stash" } unless exists
      end
    end
    enable_extension "pgcrypto"

    # Active Storage, with UUID keys. The same tables that active_storage:install makes.
    create_table :active_storage_blobs, id: :uuid do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum
      t.datetime :created_at,   null: false

      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments, id: :uuid do |t|
      t.string     :name,     null: false
      t.references :record,   null: false, polymorphic: true, index: false, type: :uuid
      t.references :blob,     null: false, type: :uuid
      t.datetime :created_at, null: false

      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records, id: :uuid do |t|
      t.belongs_to :blob, null: false, index: false, type: :uuid
      t.string :variation_digest, null: false

      t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :archives, id: :uuid do |t|
      t.text :url, null: false
      t.text :normalized_url, null: false
      t.string :host, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: "queued"
      # The Weave sub of the person who asked, when a person asked.
      t.string :requested_by_sub
      # The Weave client_id of the patch app that asked, when an app asked.
      t.string :client_id
      t.jsonb :reference, null: false, default: {}
      # reference["submission"], copied out for the idempotency index.
      t.string :submission_ref
      t.text :note
      t.datetime :completed_at
      t.timestamps

      t.index :normalized_url
      t.index :status
      t.index :created_at
      t.index :requested_by_sub
      t.index [ :client_id, :submission_ref, :normalized_url ], unique: true,
        where: "client_id IS NOT NULL AND submission_ref IS NOT NULL", name: :index_archives_idempotency
    end

    create_table :captures, id: :uuid do |t|
      t.references :archive, null: false, type: :uuid, foreign_key: true, index: false
      # "method" is taken by Ruby, so the column is method_name.
      t.string :method_name, null: false
      t.string :status, null: false, default: "queued"
      t.integer :position, null: false, default: 0
      t.text :log
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps

      t.index [ :archive_id, :method_name ], unique: true
      t.index :status
    end

    create_table :artifacts, id: :uuid do |t|
      t.references :capture, null: false, type: :uuid, foreign_key: true
      t.string :role, null: false
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false, default: 0
      t.string :sha256, null: false
      t.timestamps

      t.index :sha256
    end

    create_table :audit_events, id: :uuid do |t|
      t.string :actor_sub, null: false
      t.string :action, null: false
      t.string :subject_type, null: false
      t.string :subject_public_id, null: false
      t.text :reason, null: false
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false

      t.index :created_at
      t.index [ :subject_type, :subject_public_id ]
    end
  end
end
