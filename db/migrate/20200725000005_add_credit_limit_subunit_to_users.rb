class AddCreditLimitSubunitToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :credit_limit_subunit, :bigint, null: true, after: :picture_url
  end
end
