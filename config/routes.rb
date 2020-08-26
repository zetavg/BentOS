# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  devise_scope :user do
    root to: 'devise/registrations#edit'
  end

  devise_for :users,
             skip: :registrations,
             controllers: { omniauth_callbacks: 'users/omniauth_callbacks' },
             path_names: {
               sign_in: 'sign-in',
               sign_out: 'sign-out'
             }
  devise_scope :user do
    resource :registration,
             only: [:new, :create, :edit, :update],
             path: 'users',
             path_names: { new: 'sign-up' },
             controller: 'devise/registrations',
             as: :user_registration do
               get :cancel
             end
  end

  authenticate :user do
    namespace :me do
      resource :account, only: [:show] do
        scope module: :account do
          resources :transactions, only: [:index]
        end
      end
    end
  end
end
