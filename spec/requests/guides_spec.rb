require 'rails_helper'

RSpec.describe "Guides", type: :request do
  let(:user) { create(:user) }

  describe "GET /guides/ios_shortcut" do
    context "ログイン済みの場合" do
      before { sign_in user }

      it "200 OKを返すこと" do
        get guides_ios_shortcut_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "未ログインの場合" do
      it "404を返すこと" do
        get "/guides/ios_shortcut"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
