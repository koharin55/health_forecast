require 'rails_helper'

RSpec.describe "Mypage", type: :request do
  let(:user) { create(:user, :with_location) }

  describe "GET /mypage" do
    context "when signed in" do
      before { sign_in user }

      it "returns success" do
        get mypage_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when not signed in" do
      it "does not allow access" do
        get "/mypage"
        expect(response).to have_http_status(:not_found).or have_http_status(:redirect)
      end
    end
  end

  describe "PATCH /mypage/update_profile" do
    before { sign_in user }

    context "with valid params" do
      it "updates nickname without password" do
        patch update_profile_mypage_path, params: { user: { nickname: "新しい名前" } }
        expect(response).to redirect_to(mypage_path)
        expect(user.reload.nickname).to eq("新しい名前")
      end

      it "updates email with correct password" do
        patch update_profile_mypage_path, params: {
          user: { email: "new@example.com", current_password: "password123" }
        }
        expect(response).to redirect_to(mypage_path)
        expect(user.reload.email).to eq("new@example.com")
      end
    end

    context "with invalid params" do
      it "renders show with error for too long nickname" do
        patch update_profile_mypage_path, params: { user: { nickname: "あ" * 21 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "renders show with error for invalid email" do
        patch update_profile_mypage_path, params: { user: { email: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects email update without password" do
        patch update_profile_mypage_path, params: { user: { email: "new@example.com" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects email update with wrong password" do
        patch update_profile_mypage_path, params: {
          user: { email: "new@example.com", current_password: "wrongpassword" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /mypage/update_password" do
    before { sign_in user }

    context "with valid params" do
      it "updates password" do
        patch update_password_mypage_path, params: {
          user: {
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          }
        }
        expect(response).to redirect_to(mypage_path)
        expect(user.reload.valid_password?("newpassword456")).to be true
      end
    end

    context "with wrong current password" do
      it "renders show with error" do
        patch update_password_mypage_path, params: {
          user: {
            current_password: "wrongpassword",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /mypage/update_location" do
    before { sign_in user }

    it "updates location from prefecture" do
      patch update_location_mypage_path, params: { location_type: "prefecture", prefecture_code: "13" }
      expect(response).to redirect_to(mypage_path)
      expect(user.reload.location_name).to eq("東京都")
    end

    it "redirects with alert for missing location_type" do
      patch update_location_mypage_path, params: {}
      expect(response).to redirect_to(mypage_path)
      expect(flash[:alert]).to eq("地域の指定方法を選択してください")
    end
  end

  describe "POST /mypage/search_zipcode" do
    before { sign_in user }

    context "with valid zipcode" do
      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_return(
            status: 200,
            body: {
              status: 200,
              results: [
                {
                  "address1" => "東京都",
                  "address2" => "新宿区",
                  "address3" => "西新宿",
                  "prefcode" => "13",
                  "zipcode" => "1600023"
                }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it "returns address JSON" do
        post search_zipcode_mypage_path, params: { zipcode: "160-0023" }, as: :json
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["address"]).to include("東京都")
      end
    end

    context "with invalid zipcode" do
      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_return(
            status: 200,
            body: { status: 200, results: nil }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it "returns error JSON" do
        post search_zipcode_mypage_path, params: { zipcode: "0000000" }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end
    end
  end

  describe "POST /mypage/backfill_weather" do
    before { sign_in user }

    context "when location is not configured" do
      let(:user) { create(:user, latitude: nil, longitude: nil) }

      it "redirects with alert" do
        post backfill_weather_mypage_path
        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("先に地域を設定してください")
      end
    end

    context "when location is configured but no records" do
      it "redirects with notice about no records" do
        post backfill_weather_mypage_path
        expect(response).to redirect_to(mypage_path)
        expect(flash[:notice]).to eq("取得対象の記録がありません")
      end
    end
  end

  describe "DELETE /mypage/destroy_account" do
    before { sign_in user }

    it "destroys the user account" do
      expect {
        delete destroy_account_mypage_path
      }.to change(User, :count).by(-1)
    end

    it "redirects to sign in page" do
      delete destroy_account_mypage_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "ensure_nickname_set filter" do
    context "when nickname is not set" do
      let(:user_without_nickname) { create(:user, :without_nickname, :with_location) }

      before { sign_in user_without_nickname }

      it "redirects to mypage from dashboard" do
        get authenticated_root_path
        expect(response).to redirect_to(mypage_path)
      end

      it "allows access to mypage itself" do
        get mypage_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when nickname is set" do
      before do
        sign_in user
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 200, body: { current: {} }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it "allows access to dashboard" do
        get authenticated_root_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /settings (redirect)" do
    before { sign_in user }

    it "redirects to /mypage" do
      get "/settings"
      expect(response).to redirect_to("/mypage")
    end
  end
end
