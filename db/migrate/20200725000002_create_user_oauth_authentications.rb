# frozen_string_literal: true

class CreateUserOAuthAuthentications < ActiveRecord::Migration[6.0]
  def change
    create_table :user_oauth_authentications, id: :uuid do |t|
      t.references :user, foreign_key: true, type: :uuid
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :access_token
      t.datetime :access_token_expires_at
      t.string :refresh_token
      t.jsonb :data

      t.boolean :sync_data, null: false, default: false

      t.timestamps
    end

    add_index :user_oauth_authentications, [:provider, :uid], unique: true
  end
end
