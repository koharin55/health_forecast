require 'rails_helper'

RSpec.describe WeeklyReport, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      report = build(:weekly_report)
      expect(report).to be_valid
    end

    it 'validates presence of week_start' do
      report = build(:weekly_report, week_start: nil)
      expect(report).not_to be_valid
      expect(report.errors[:week_start]).to be_present
    end

    it 'validates presence of week_end' do
      report = build(:weekly_report, week_end: nil)
      expect(report).not_to be_valid
      expect(report.errors[:week_end]).to be_present
    end

    it 'validates presence of content' do
      report = build(:weekly_report, content: nil)
      expect(report).not_to be_valid
      expect(report.errors[:content]).to be_present
    end

    it 'validates uniqueness of week_start scoped to user and week_end' do
      user = create(:user)
      create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      duplicate = build(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:week_start]).to be_present
    end

    it 'allows same week_start with different week_end for same user' do
      user = create(:user)
      create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      report2 = build(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 10))
      expect(report2).to be_valid
    end

    it 'allows same week_start for different users' do
      user1 = create(:user)
      user2 = create(:user)

      create(:weekly_report, user: user1, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))
      report2 = build(:weekly_report, user: user2, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(report2).to be_valid
    end

    it 'validates week_end is after week_start' do
      report = build(:weekly_report, week_start: Date.new(2026, 2, 10), week_end: Date.new(2026, 2, 5))
      expect(report).not_to be_valid
      expect(report.errors[:week_end]).to be_present
    end
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by week_start descending' do
        user = create(:user)
        old_report = create(:weekly_report, user: user, week_start: Date.new(2026, 1, 27), week_end: Date.new(2026, 2, 2))
        new_report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

        expect(WeeklyReport.recent.first).to eq(new_report)
        expect(WeeklyReport.recent.last).to eq(old_report)
      end
    end

    describe '.for_user' do
      it 'returns only reports for the specified user' do
        user1 = create(:user)
        user2 = create(:user)
        report1 = create(:weekly_report, user: user1)
        create(:weekly_report, user: user2)

        expect(WeeklyReport.for_user(user1)).to eq([report1])
      end
    end
  end

  describe '.find_for_week' do
    it 'returns report for the specified week' do
      user = create(:user)
      report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3))

      expect(WeeklyReport.find_for_week(user, Date.new(2026, 2, 3))).to eq(report)
    end

    it 'returns nil when no report exists' do
      user = create(:user)

      expect(WeeklyReport.find_for_week(user, Date.new(2026, 2, 3))).to be_nil
    end
  end

  describe '.find_for_period' do
    it 'returns report for the specified period' do
      user = create(:user)
      report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(WeeklyReport.find_for_period(user, Date.new(2026, 2, 3), Date.new(2026, 2, 9))).to eq(report)
    end

    it 'returns nil when no report exists for the period' do
      user = create(:user)
      create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(WeeklyReport.find_for_period(user, Date.new(2026, 2, 3), Date.new(2026, 2, 10))).to be_nil
    end
  end

  describe '.latest_for_user' do
    it 'returns the most recent report for the user' do
      user = create(:user)
      create(:weekly_report, user: user, week_start: Date.new(2026, 1, 27), week_end: Date.new(2026, 2, 2))
      new_report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(WeeklyReport.latest_for_user(user)).to eq(new_report)
    end
  end

  describe '.monthly_tokens_used' do
    it 'returns total tokens used in the month' do
      user = create(:user)
      create(:weekly_report, user: user, tokens_used: 500,
             week_start: Date.new(2026, 2, 1), week_end: Date.new(2026, 2, 7),
             created_at: Date.new(2026, 2, 5))
      create(:weekly_report, user: user, tokens_used: 300,
             week_start: Date.new(2026, 2, 8), week_end: Date.new(2026, 2, 14),
             created_at: Date.new(2026, 2, 12))

      expect(WeeklyReport.monthly_tokens_used(user, Date.new(2026, 2, 15))).to eq(800)
    end

    it 'excludes reports from other months' do
      user = create(:user)
      create(:weekly_report, user: user, tokens_used: 500,
             week_start: Date.new(2026, 1, 20), week_end: Date.new(2026, 1, 26),
             created_at: Date.new(2026, 1, 25))
      create(:weekly_report, user: user, tokens_used: 300,
             week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9),
             created_at: Date.new(2026, 2, 5))

      expect(WeeklyReport.monthly_tokens_used(user, Date.new(2026, 2, 15))).to eq(300)
    end

    it 'returns 0 when no reports exist' do
      user = create(:user)

      expect(WeeklyReport.monthly_tokens_used(user)).to eq(0)
    end
  end

  describe '#previous_report' do
    it 'returns the report with the nearest earlier week_start' do
      user = create(:user)
      old_report = create(:weekly_report, user: user, week_start: Date.new(2026, 1, 27), week_end: Date.new(2026, 2, 2))
      current_report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(current_report.previous_report).to eq(old_report)
    end

    it 'returns nil when no earlier report exists' do
      user = create(:user)
      report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(report.previous_report).to be_nil
    end

    it 'does not return reports from other users' do
      user1 = create(:user)
      user2 = create(:user)
      create(:weekly_report, user: user2, week_start: Date.new(2026, 1, 27), week_end: Date.new(2026, 2, 2))
      current_report = create(:weekly_report, user: user1, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(current_report.previous_report).to be_nil
    end
  end

  describe '#next_report' do
    it 'returns the report with the nearest later week_start' do
      user = create(:user)
      current_report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))
      new_report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 10), week_end: Date.new(2026, 2, 16))

      expect(current_report.next_report).to eq(new_report)
    end

    it 'returns nil when no later report exists' do
      user = create(:user)
      report = create(:weekly_report, user: user, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(report.next_report).to be_nil
    end

    it 'does not return reports from other users' do
      user1 = create(:user)
      user2 = create(:user)
      current_report = create(:weekly_report, user: user1, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))
      create(:weekly_report, user: user2, week_start: Date.new(2026, 2, 10), week_end: Date.new(2026, 2, 16))

      expect(current_report.next_report).to be_nil
    end
  end

  describe '#period_display' do
    it 'returns formatted period string' do
      report = build(:weekly_report, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(report.period_display).to eq('02/03〜02/09')
    end
  end

  describe '#period_display_ja' do
    it 'returns Japanese formatted period string' do
      report = build(:weekly_report, week_start: Date.new(2026, 2, 3), week_end: Date.new(2026, 2, 9))

      expect(report.period_display_ja).to eq('2026年02月03日〜02月09日')
    end
  end
end
