# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::BookingsController do
  render_views

  let(:group) { groups(:top_layer) }
  let(:member) { people(:bottom_member) }
  let(:fee) { BankingDe::Booking.find_by!(amount: 85) }

  def fee_row(person_id, year: 2026, amount: 85)
    {person_id: person_id, purpose: "membership_fee", year: year, amount: amount}
  end

  def allocate(rows, **params)
    post :allocate, params: {group_id: group.id, id: fee.id, rows: rows, **params}
  end

  before do
    register_test_purposes
    import_camt("camt052_v08.xml")
  end

  context "with finance permission" do
    before { sign_in(people(:top_leader)) }

    it "lists open bookings with suggestions and one-click confirmation" do
      get :index, params: {group_id: group.id}

      expect(response).to be_successful
      expect(response.body).to include "MITGLIEDSBEITRAG 2026"
      expect(response.body).to include "Member Bottom"
      expect(response.body).to include "Sammellastschrift"
      expect(response.body).to include "Kontoimport"
      expect(response.body).not_to include "Some Shop"
    end

    it "shows a booking with the allocation form" do
      get :show, params: {group_id: group.id, id: fee.id}

      expect(response).to be_successful
      expect(response.body).to include "rows[0][person_id]"
      expect(response.body).to include "DE52 1203 0000 1111 1111 11"
    end

    it "allocates and continues with the next open booking" do
      allocate({"0" => fee_row(member.id, amount: "85,00"), "1" => fee_row("", amount: "")})

      expect(fee.reload).to be_done
      expect(fee.allocations.map(&:person)).to eq [member]
      expect(response).to redirect_to(%r{/bank_bookings/\d+})
      expect(flash[:notice]).to be_present
    end

    it "returns to the list after one-click confirmation" do
      allocate({"0" => fee_row(member.id)}, return_to: "index")

      expect(response).to redirect_to(group_bank_bookings_path(group))
    end

    it "shows an error for invalid rows" do
      allocate({"0" => fee_row(member.id, year: "")})

      expect(fee.reload).to be_open
      expect(flash[:alert]).to be_present
    end

    it "does not allocate people outside the layer" do
      outside = Fabricate(:person)

      expect { allocate({"0" => fee_row(outside.id)}) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "ignores, reopens and reverts" do
      post :ignore, params: {group_id: group.id, id: fee.id, note: "Kurs"}
      expect(fee.reload).to be_ignored

      post :reopen, params: {group_id: group.id, id: fee.id}
      expect(fee.reload).to be_open

      BankingDe::Allocator.new(fee, people(:top_leader))
        .allocate([{person_id: member.id, purpose: "membership_fee", year: 2026, amount: 85}])
      get :show, params: {group_id: group.id, id: fee.id}
      expect(response.body).to include "Zuordnung zurücknehmen"

      post :revert, params: {group_id: group.id, id: fee.id}
      expect(fee.reload).to be_open
    end

    it "is only available on layers" do
      expect { get :index, params: {group_id: groups(:top_group).id} }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "without finance permission" do
    before { sign_in(member) }

    it "denies access" do
      expect { get :index, params: {group_id: group.id} }.to raise_error(CanCan::AccessDenied)
      expect {
        get :show, params: {group_id: group.id, id: fee.id}
      }.to raise_error(CanCan::AccessDenied)
    end
  end
end
