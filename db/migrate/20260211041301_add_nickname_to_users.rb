class AddNicknameToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :nickname, :string, limit: 20
  end
end
