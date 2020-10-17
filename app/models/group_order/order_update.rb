# frozen_string_literal: true

class GroupOrder::OrderUpdate < ActiveType::Object
  nests_one :order, scope: proc { GroupOrder::Order.all }
  attribute :content, :json
  attribute :private, :boolean, default: false

  validate :group_is_open
  validate :valid_order
  validate :valid_user_authorization_hold

  before_save :update_order_with_transaction_hold

  attr_reader :order_to_update, :create_or_update_user_authorization_hold_to_submit, :updated_order

  def self.load(order)
    new(order: order, content: order.content, private: order.private)
  end

  private

  def build_order_to_update
    if @order_to_update.nil? || @order_to_update&.object_id == order.object_id
      # Get a new instance of GroupOrder::Order for updating
      @order_to_update = GroupOrder::Order.find(order.id)
    end

    @order_to_update.content = content unless content.nil?
    @order_to_update.private = private unless private.nil?

    @order_to_update._really_update = true
  end

  def build_create_or_update_user_authorization_hold
    build_order_to_update

    @create_or_update_user_authorization_hold_to_submit = Accounting::CreateOrUpdateUserAuthorizationHold.new(
      uuid: @order_to_update.authorization_hold_uuid,
      user: @order_to_update.user,
      amount: @order_to_update.amount,
      transfer_code: :pay_group_order,
      partner_account: @order_to_update.group.account
    )
  end

  def group_is_open
    build_order_to_update
    return if @order_to_update.group&.reload&.state == 'open'

    errors.add(:group, :not_open, state: @order_to_update.group.state)
  end

  def valid_order
    build_order_to_update

    @order_to_update.validate
    @order_to_update.errors.details.each do |attrname, errs|
      next if attrname != :base && self.class._virtual_column_names.exclude?(attrname.to_s)

      errs.each do |err|
        errors.add(attrname, err[:error], err.except(:error))
      end
    end

    # # TODO: do not clear ???
    # errors.clear(:order)
  end

  def valid_user_authorization_hold
    build_create_or_update_user_authorization_hold

    @create_or_update_user_authorization_hold_to_submit.validate

    return unless @create_or_update_user_authorization_hold_to_submit.errors.details[:base].is_a? Array

    @create_or_update_user_authorization_hold_to_submit.errors.details[:base].each do |err|
      errors.add(:base, err[:error], err.except(:error))
    end
  end

  def update_order_with_transaction_hold
    build_order_to_update
    build_create_or_update_user_authorization_hold

    @create_or_update_user_authorization_hold_to_submit.transaction do
      @order_to_update.save!
      @create_or_update_user_authorization_hold_to_submit.save!
    end

    @updated_order = @order_to_update
    @updated_order._really_update = false
    self.order = @updated_order
  end
end
