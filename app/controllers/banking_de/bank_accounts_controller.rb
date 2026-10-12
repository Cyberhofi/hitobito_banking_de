# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Bank account and SEPA direct debit mandate of a person
class BankingDe::BankAccountsController < ApplicationController
  PERMITTED = [:iban, :account_holder, :mandate_reference, :mandate_signed_on,
    :mandate_revoked_on].freeze

  before_action :authorize_person

  helper_method :group, :person, :entry

  def edit
  end

  def update
    assign_attributes

    if entry.save
      redirect_to group_person_path(group, person), notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    person.banking_de_bank_account&.destroy!
    redirect_to group_person_path(group, person), notice: t(".success")
  end

  private

  def group
    @group ||= Group.find(params[:group_id])
  end

  def person
    @person ||= Person.find(params[:person_id])
  end

  def entry
    @bank_account ||= person.banking_de_bank_account || person.build_banking_de_bank_account
  end

  def authorize_person
    group # the group sheet needs @group
    authorize!(:update_bank_account, person)
  end

  def model_params
    params.require(:bank_account).permit(*PERMITTED)
  end

  def assign_attributes
    entry.assign_attributes(model_params)
    entry.source = "manual" if entry.iban_changed?
    entry.created_by ||= current_user
    entry.updated_by = current_user
    clear_return if params.dig(:bank_account, :clear_return) == "1"
  end

  def clear_return
    entry.last_return_reason = nil
    entry.last_return_on = nil
  end
end
