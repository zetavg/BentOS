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

  attr_reader :order_to_create, :create_or_update_user_authorization_hold_to_submit, :created_order

  def order
    created_order
  end

  private

  def build_order_to_create
    @order_to_create = GroupOrder::Order.new(
      user: user,
      group: group,
      content: content,
      private: private,
      authorization_hold_uuid: SecureRandom.uuid,
      _really_update: true
    )
    @order_to_create.validate
    @order_to_create
  end

  def build_create_or_update_user_authorization_hold
    build_order_to_create

    @create_or_update_user_authorization_hold_to_submit = Accounting::CreateOrUpdateUserAuthorizationHold.new(
      uuid: @order_to_create.authorization_hold_uuid,
      user: @order_to_create.user,
      amount: @order_to_create.amount,
      transfer_code: :pay_group_order,
      partner_account: @order_to_create.group.account
    )
  end

  def group_is_open
    build_order_to_create
    return unless @order_to_create.group

    return if @order_to_create.group&.reload&.state == 'open'

    errors.add(:group, :not_open, state: @order_to_create.group.state)
  end

  def valid_order
    build_order_to_create

    @order_to_create.validate
    @order_to_create.errors.details.each do |attrname, errs|
      next if attrname != :base && self.class._virtual_column_names.exclude?(attrname.to_s)

      errs.each do |err|
        errors.add(attrname, err[:error], err.except(:error))
      end
    end
  end

  def valid_user_authorization_hold
    build_create_or_update_user_authorization_hold

    @create_or_update_user_authorization_hold_to_submit.validate

    return unless @create_or_update_user_authorization_hold_to_submit.errors.details[:base].is_a? Array

    @create_or_update_user_authorization_hold_to_submit.errors.details[:base].each do |err|
      errors.add(:base, err[:error], err.except(:error))
    end
  end

  def create_order_with_transaction_hold
    build_order_to_create

    create_or_update_user_authorization_hold = Accounting::CreateOrUpdateUserAuthorizationHold.new(
      uuid: @order_to_create.authorization_hold_uuid,
      user: user,
      amount: @order_to_create.amount,
      transfer_code: :pay_group_order,
      partner_account: @order_to_create.group.account
    )

    create_or_update_user_authorization_hold.transaction do
      if @order_to_create&.group&.reload&.state != 'open'
        raise StandardError,
              "Grop #{@order_to_create&.group_id} state is not open, it's #{@order_to_create&.group&.state}"
      end

      @order_to_create.save!
      create_or_update_user_authorization_hold.detail = @order_to_create
      create_or_update_user_authorization_hold.save!
    end

    @created_order = @order_to_create
    @created_order._really_update = false
  end
end
