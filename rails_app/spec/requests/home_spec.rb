# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders successfully for guests" do
      get root_path, headers: default_headers
      expect(response).to have_http_status(:ok)
    end

    it "redirects authenticated users to their profile" do
      user = create(:user)
      sign_in user

      get root_path, headers: default_headers

      expect(response).to redirect_to(profile_path)
    end
  end
end
