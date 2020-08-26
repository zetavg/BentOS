# frozen_string_literal: true

class Me::AccountsController < ApplicationController
  def show
    redirect_to me_account_transactions_path
  end
end
