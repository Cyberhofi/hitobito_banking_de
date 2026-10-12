# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::BankAccountsController do
  render_views

  let(:person) { people(:bottom_member) }
  let(:group) { groups(:bottom_layer_one) }
  let(:params) { {group_id: group.id, person_id: person.id} }

  context "with finance permission" do
    before { sign_in(people(:top_leader)) }

    it "shows the form" do
      get :edit, params: params

      expect(response).to be_successful
      expect(response.body).to include "Mandatsreferenz"
    end

    it "stores bank account and mandate" do
      attrs = {iban: "DE89 3704 0044 0532 0130 00", account_holder: "Bottom Member",
               mandate_reference: "M-1", mandate_signed_on: "01.03.2026"}
      patch :update, params: params.merge(bank_account: attrs)

      account = person.reload.banking_de_bank_account
      expect(account).to have_attributes(iban: "DE89370400440532013000", mandate_reference: "M-1",
        mandate_signed_on: Date.new(2026, 3, 1), source: "manual", updated_by: people(:top_leader))
      expect(account).to be_collectible
      expect(response).to redirect_to(group_person_path(group, person))
    end

    it "shows errors" do
      patch :update, params: params.merge(bank_account: {iban: "DE00 1234"})

      expect(response).to have_http_status(:unprocessable_content)
      expect(person.reload.banking_de_bank_account).to be_nil
    end

    it "clears a returned direct debit" do
      BankingDe::BankAccount.create!(person: person, iban: "DE89370400440532013000",
        last_return_reason: "AC04", last_return_on: Date.current)
      patch :update,
        params: params.merge(bank_account: {iban: "DE89370400440532013000", clear_return: "1"})

      expect(person.reload.banking_de_bank_account.last_return_reason).to be_nil
    end

    it "deletes the bank account" do
      BankingDe::BankAccount.create!(person: person, iban: "DE89370400440532013000")
      delete :destroy, params: params

      expect(person.reload.banking_de_bank_account).to be_nil
    end
  end

  it "denies access without finance permission" do
    member = Fabricate(Group::BottomGroup::Member.sti_name,
      group: groups(:bottom_group_one_one)).person
    sign_in(member)

    expect { get :edit, params: params.merge(person_id: member.id) }
      .to raise_error(CanCan::AccessDenied)
  end
end
