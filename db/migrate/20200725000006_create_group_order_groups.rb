class CreateGroupOrderGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :group_order_groups, id: :uuid do |t|
      t.string :state, limit: 32, index: true, null: false
      t.references :organizer, null: false, foreign_key: { to_table: :users }, type: :uuid

      t.string :name, null: false
      t.boolean :private, null: false, default: false

      t.datetime :to_be_closed_at, null: false
      t.datetime :expected_delivery_time, null: false

      t.bigint :group_minimum_amount_subunit, null: false, default: 0
      t.integer :group_minimum_sets, null: false, default: 0
      t.bigint :group_maximum_amount_subunit, null: true
      t.integer :group_maximum_sets, null: true

      t.jsonb :menu, null: false

      t.timestamps
    end
  end
end
