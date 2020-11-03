class CreateGroupOrderOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :group_order_orders, id: :uuid do |t|
      t.string :state, limit: 32, index: true, null: false
      t.references :group, null: false, foreign_key: { to_table: :group_order_groups }, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.boolean :private, null: false, default: false

      t.bigint :amount_subunit, null: false

      t.jsonb :content, null: false

      t.uuid :authorization_hold_uuid, null: false, default: 'gen_random_uuid()'

      t.timestamps
    end

    add_index :group_order_orders, :authorization_hold_uuid, unique: true
  end
end
