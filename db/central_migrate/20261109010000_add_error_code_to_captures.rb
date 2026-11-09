# The machine-readable reason of a failed capture (Capturers::CODES), next to the message in
# `error`. Patch apps read it from the API to tell the submitter what to fix.
class AddErrorCodeToCaptures < ActiveRecord::Migration[8.1]
  def change
    add_column :captures, :error_code, :string
  end
end
