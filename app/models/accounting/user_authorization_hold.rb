# frozen_string_literal: true

class Accounting::UserAuthorizationHold < ApplicationRecord
  include AASM

  monetize :amount_subunit, as: :amount

  def partner_account
    DoubleEntry.account(partner_account_identifier&.to_sym, scope_identity: partner_account_scope_identity)
  rescue DoubleEntry::UnknownAccount
    nil
  end

  def partner_account=(double_entry_account)
    unless double_entry_account.is_a?(DoubleEntry::Account::Instance)
      self.partner_account_identifier = nil
      self.partner_account_scope_identity = nil
      return
    end

    self.partner_account_identifier = double_entry_account.identifier
    self.partner_account_scope_identity = double_entry_account.scope_identity
  end

  belongs_to :user
  belongs_to :detail, polymorphic: true, optional: true

  aasm column: :state do
    state :holding, initial: true
    state :closed
    state :reversed

    event :capture do
      transitions from: :holding, to: :closed
    end

    event :reverse do
      transitions from: :holding, to: :reversed
    end
  end

  # Do not allow calling lifecycle events without saving
  private :capture
  private :reverse

  validates :amount, numericality: { greater_than: 0 }, allow_blank: false
  validate :transfer_code_valid
  validate :partner_account_valid

  class << self
    def available_transfers
      @@available_transfers ||= DoubleEntry.configuration.transfers.all.filter { |t| t.from == :user_account } # rubocop:disable Style/ClassVars
    end

    def available_transfer_codes
      @@available_transfer_codes ||= available_transfers.map(&:code) # rubocop:disable Style/ClassVars
    end
  end

  private

  def transfer_code_valid
    return if self.class.available_transfer_codes.include?(transfer_code&.to_sym)

    errors.add(:transfer_code, :invalid, available_transfer_codes: self.class.available_transfer_codes)
  end

  def partner_account_valid
    transfer = self.class.available_transfers.find { |t| t.code == transfer_code&.to_sym }
    return if transfer.blank? # Will already fail transfer_code_valid validation
    return if transfer.to == partner_account&.identifier

    errors.add(:partner_account, :invalid, available_partner_account_identifier: transfer.to)
  end
end
