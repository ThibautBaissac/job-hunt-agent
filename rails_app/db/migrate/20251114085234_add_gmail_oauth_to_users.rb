class AddGmailOauthToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_uid, :string
    add_column :users, :gmail_connected, :boolean, default: false, null: false
    add_column :users, :google_access_token, :text
    add_column :users, :google_refresh_token, :text
    add_column :users, :google_token_expires_at, :datetime

    add_index :users, :google_uid, unique: true
  end
end
