require 'rails_helper'

RSpec.describe ZipcodeService do
  describe '.search' do
    context 'with valid zipcode' do
      let(:api_response) do
        {
          "message" => nil,
          "results" => [
            {
              "address1" => "東京都",
              "address2" => "新宿区",
              "address3" => "西新宿",
              "kana1" => "トウキョウト",
              "kana2" => "シンジュクク",
              "kana3" => "ニシシンジュク",
              "prefcode" => "13",
              "zipcode" => "1600023"
            }
          ],
          "status" => 200
        }
      end

      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns address information' do
        result = described_class.search("160-0023")

        expect(result[:zipcode]).to eq("1600023")
        expect(result[:prefecture_code]).to eq("13")
        expect(result[:prefecture_name]).to eq("東京都")
        expect(result[:city]).to eq("新宿区")
        expect(result[:town]).to eq("西新宿")
        expect(result[:full_address]).to eq("東京都新宿区西新宿")
        expect(result[:latitude]).to be_present
        expect(result[:longitude]).to be_present
      end

      it 'normalizes zipcode with hyphens' do
        result = described_class.search("160-0023")
        expect(result[:zipcode]).to eq("1600023")
      end

      it 'normalizes zipcode without hyphens' do
        result = described_class.search("1600023")
        expect(result[:zipcode]).to eq("1600023")
      end
    end

    context 'with invalid zipcode format' do
      it 'raises NotFoundError for short zipcode' do
        expect { described_class.search("123") }
          .to raise_error(ZipcodeService::NotFoundError, /7桁/)
      end

      it 'raises NotFoundError for non-numeric zipcode' do
        expect { described_class.search("abcdefg") }
          .to raise_error(ZipcodeService::NotFoundError, /7桁/)
      end
    end

    context 'when zipcode not found' do
      let(:api_response) do
        {
          "message" => nil,
          "results" => nil,
          "status" => 200
        }
      end

      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises NotFoundError' do
        expect { described_class.search("0000000") }
          .to raise_error(ZipcodeService::NotFoundError, /見つかりません/)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ApiError' do
        expect { described_class.search("1600023") }
          .to raise_error(ZipcodeService::ApiError)
      end
    end

    context 'when API times out' do
      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_timeout
      end

      it 'raises ApiError' do
        expect { described_class.search("1600023") }
          .to raise_error(ZipcodeService::ApiError, /タイムアウト/)
      end
    end
  end
end
