# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::StatementsController do
  render_views

  let(:group) { groups(:top_layer) }

  def upload(name)
    Rack::Test::UploadedFile.new(camt_file(name), "application/xml")
  end

  context "with finance permission" do
    before { sign_in(people(:top_leader)) }

    it "shows the upload form" do
      get :new, params: {group_id: group.id}

      expect(response).to be_successful
      expect(response.body).to include "camt.052"
    end

    it "imports uploaded files" do
      post :create, params: {group_id: group.id,
                             bank_statement: {files: [upload("camt052_v08.xml"),
                               upload("camt053_v02.xml")]}}

      expect(response).to redirect_to(group_bank_bookings_path(group))
      expect(flash[:notice]).to include "5 neue Buchungen"
      expect(BankingDe::Booking.where(group: group).count).to eq 5
    end

    it "requires a file" do
      post :create, params: {group_id: group.id}

      expect(response).to redirect_to(new_group_bank_statement_path(group))
    end

    it "lists the statements" do
      import_camt("camt052_v08.xml", "camt053_v02.xml")
      get :index, params: {group_id: group.id}

      expect(response).to be_successful
      expect(response.body).to include "camt053_v02.xml"
      expect(response.body).to include "505.00" # number format of the core test locale
    end
  end

  it "denies access without finance permission" do
    sign_in(people(:bottom_member))

    expect { get :new, params: {group_id: group.id} }.to raise_error(CanCan::AccessDenied)
  end
end
