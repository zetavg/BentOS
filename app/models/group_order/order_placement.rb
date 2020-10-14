# frozen_string_literal: true

class GroupOrder::OrderPlacement < ActiveType::Object
  nests_one :user, scope: proc { User.all }
  nests_one :group, scope: proc { Group.where(state: :open) }
  attribute :content, :json
  attribute :private, :boolean, default: false

  validate :group_is_open
  validate :valid_order
  validate :valid_user_authorization_hold

  before_save :create_order_with_transaction_hold

  attr_reader :created_order

  def order
    created_order
  end

  def order_to_create
    @order
  end

  def create_or_update_user_authorization_hold_to_submit
    @create_or_update_user_authorization_hold
  end

  private

  def build_order
    @order = GroupOrder::Order.new(
      user: user,
      group: group,
      content: content,
      private: private,
      authorization_hold_uuid: SecureRandom.uuid,
      _really_update: true
    )
    @order.validate
    @order
  end

  def build_create_or_update_user_authorization_hold
    build_order

    @create_or_update_user_authorization_hold = Accounting::CreateOrUpdateUserAuthorizationHold.new(
      uuid: @order.authorization_hold_uuid,
      user: @order.user,
      amount: @order.amount,
      transfer_code: :pay_group_order,
      partner_account: @order.group.account
    )
  end

  def group_is_open
    build_order
    return unless @order.group

    return if @order.group&.reload&.state == 'open'

    errors.add(:group, :not_open, state: @order.group.state)
  end

  def valid_order
    build_order

    @order.validate
    @order.errors.details.each do |attrname, errs|
      next if attrname != :base && self.class._virtual_column_names.exclude?(attrname.to_s)

      errs.each do |err|
        errors.add(attrname, err[:error], err.except(:error))
      end
    end
  end

  def valid_user_authorization_hold
    build_create_or_update_user_authorization_hold

    @create_or_update_user_authorization_hold.validate

    return unless @create_or_update_user_authorization_hold.errors.details[:base].is_a? Array

    @create_or_update_user_authorization_hold.errors.details[:base].each do |err|
      errors.add(:base, err[:error], err.except(:error))
    end
  end

  def create_order_with_transaction_hold
    build_order

    create_or_update_user_authorization_hold = Accounting::CreateOrUpdateUserAuthorizationHold.new(
      uuid: @order.authorization_hold_uuid,
      user: user,
      amount: @order.amount,
      transfer_code: :pay_group_order,
      partner_account: @order.group.account
    )

    create_or_update_user_authorization_hold.transaction do
      if @order&.group&.reload&.state != 'open'
        raise StandardError, "Grop #{@order&.group_id} state is not open, it's #{@order&.group&.state}"
      end

      @order.save!
      create_or_update_user_authorization_hold.detail = @order
      create_or_update_user_authorization_hold.save!
    end

    @created_order = @order
  end
end
