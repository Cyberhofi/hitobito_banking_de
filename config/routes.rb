# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

Rails.application.routes.draw do
  extend LanguageRouteScope

  language_scope do
    resources :groups, only: [] do
      scope module: "banking_de" do
        resources :bank_bookings, only: [:index, :show], controller: "bookings" do
          member do
            post :allocate
            post :revert
            post :ignore
            post :reopen
          end
        end
        resources :bank_statements, only: [:index, :new, :create], controller: "statements"

        resources :people, only: [] do
          resource :bank_account, only: [:edit, :update, :destroy], controller: "bank_accounts"
        end
      end
    end
  end
end
