# frozen_string_literal: true

class Me::Account::TransactionsController < ApplicationController
  def index
    @transactions = current_user.account_transactions.order(created_at: :desc).page(params[:page])
  end
end
