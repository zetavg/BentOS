class CreateGroupOrderOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :group_order_orders, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :group, null: false, foreign_key: { to_table: :group_order_groups }, type: :uuid

      t.jsonb :content, null: false
      t.boolean :private, null: false, default: false

      t.bigint :amount_subunit, null: false
      t.uuid :authorization_hold_uuid, null: false, default: 'gen_random_uuid()'

      t.timestamps
    end
  end
end
