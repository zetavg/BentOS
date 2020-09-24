# frozen_string_literal: true

class Accounting::CreateOrUpdateUserAuthorizationHold < ActiveType::Object
  nests_one :user, scope: proc { User.all }
  attribute :uuid, :uuid

  attribute :amount, :decimal

  attribute :transfer_code, :string
  attribute :partner_account

  nests_one :detail
  attribute :metadata, :json

  validates :user, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_blank: false
  validate :valid_user_authorization_hold

  before_validation :init_attributes_from_user_authorization_hold

  before_save :create_or_update_user_authorization_hold

  def user_authorization_hold
    unless uuid.present? && @user_authorization_hold&.id == uuid
      @user_authorization_hold = Accounting::UserAuthorizationHold.find_or_initialize_by(id: uuid)
    end

    @user_authorization_hold.assign_attributes(
      attributes.except('uuid').filter { |_, v| v.present? }
    )

    @user_authorization_hold
  end

  def accounts_to_lock_during_transaction
    [user.account]
  end

  def transaction(*more_accounts_to_lock, &_block)
    DoubleEntry.lock_accounts(*accounts_to_lock_during_transaction, *more_accounts_to_lock) do
      user.lock_authorization_holds!
      yield if block_given?
    end
  ensure
    reload
  end

  private

  def do_create_or_update_user_authorization_hold
    DoubleEntry.lock_accounts(*accounts_to_lock_during_transaction) do
      h = user_authorization_hold
      h.save!
    end
  end

  def create_or_update_user_authorization_hold
    unless wrapped_in_transaction?
      transaction do
        do_create_or_update_user_authorization_hold
      end

      return
    end

    do_create_or_update_user_authorization_hold
  end

  def init_attributes_from_user_authorization_hold
    h = user_authorization_hold
    return if h.blank?

    self.user = h.user
    self.amount = h.amount
    self.partner_account = h.partner_account
    self.detail = h.detail
    assign_attributes(
      h.attributes.filter { |k| self.class._virtual_column_names.include?(k) }
    )
  end

  def valid_user_authorization_hold
    h = user_authorization_hold

    errors.add(:uuid, :invalid_uuid) if h.id.blank?
    errors.add(:uuid, :user_authorization_hold_closed) unless h.holding?

    h.validate
    h.errors.details.each do |attrname, errs|
      next if attrname != :base && self.class._virtual_column_names.exclude?(attrname.to_s)

      errs.each do |err|
        errors.add(attrname, err[:error], err.except(:error))
      end
    end
  end

  def wrapped_in_transaction?
    running_inside_transactional_fixtures = DoubleEntry::Locking.configuration.running_inside_transactional_fixtures
    ActiveRecord::Base.connection.open_transactions > (running_inside_transactional_fixtures ? 1 : 0)
  end
end
