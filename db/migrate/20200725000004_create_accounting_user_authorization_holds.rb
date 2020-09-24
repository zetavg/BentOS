class CreateAccountingUserAuthorizationHolds < ActiveRecord::Migration[6.0]
  def change
    create_table :accounting_user_authorization_holds, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :state, limit: 32, index: true, null: false
      t.bigint :amount_subunit, null: false

      t.string :transfer_code, null: false
      t.string :partner_account_identifier, null: false
      t.string :partner_account_scope_identity

      t.references :capture_line, foreign_key: { to_table: :double_entry_lines }, null: true

      t.references :detail, polymorphic: true, null: true, type: :uuid, index: { name: :index_accounting_user_authorization_holds_on_detail }
      if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
        t.jsonb 'metadata'
      else
        t.json 'metadata'
      end

      t.timestamps
    end
  end
end
