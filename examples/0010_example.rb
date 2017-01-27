# いろんな動作確認

require "bundler/setup"
Bundler.require(:default)

FileUtils.rm_f(Dir["*.sqlite3"])

database_config = {
  "blue"  => {"adapter" => "sqlite3", "database" => "blue.sqlite3"},
  "green" => {"adapter" => "sqlite3", "database" => "green.sqlite3"},
}.with_indifferent_access

begin
  ActiveRecord::Base.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
  ActiveSupport::LogSubscriber.colorize_logging = false
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.configurations = database_config # migration を実行するため kamome 用の shard_names を環境と見なして設定

  database_config.keys.each do |key|
    ActiveRecord::Base.establish_connection(key)
    silence_stream(STDOUT) do
      ActiveRecord::Schema.define do
        create_table :users, force: true do |t|
          t.string :name, null: false
        end
      end
    end
  end
end

# 綺麗にする
db_clean = -> {
  database_config.keys.each do |key|
    silence_stream(STDOUT) do
      ActiveRecord::Base.establish_connection(key)
      ActiveRecord::Base.connection.execute("DELETE FROM users")
    end
  end
}

# Kamome の初期設定
Kamome.config.database_config = database_config
ActiveRecord::Base.include(Kamome::Model)

class User < ActiveRecord::Base
  validates :name, presence: true
end

# kamome を実行したモデルだけが影響を受ける
User.kamome_enable?             # => false
User.kamome
User.kamome_enable?             # => true

# target を設定せずに実行するとエラーになる
User.count rescue $!            # => #<Kamome::TargetNotFound: [31mKamome.target has not been set. [User.connection][0m>

# 基本的な使い方 (でも target はグローバル変数風なので、できれば anchor を使った方がいい)
Kamome.target = :blue
User.create!(name: 'blue')
User.count                      # => 1

Kamome.target = :green
User.create!(name: 'green')
User.count                      # => 1

db_clean.call

# Kamome.anchor の戻値はブロックの戻値を返す
Kamome.anchor(:green) { "ok" } # => "ok"

# Kamome.anchor は target を一時的に切り替える
Kamome.target = :blue                   # => :blue
Kamome.anchor(:green) { Kamome.target } # => :green
Kamome.target                           # => :blue

# anchor 入れ子にできる
Kamome.target = nil
Kamome.anchor(:blue) do
  Kamome.target                 # => :blue
  Kamome.anchor(:green) do
    Kamome.target               # => :green
  end
  Kamome.target                 # => :blue
end
Kamome.target                   # => nil

# 入れ子にした状態で User を作ってみて個数を確認
Kamome.anchor(:blue) do
  User.create!(name: 'blue')
  Kamome.anchor(:green) do
    User.create!(name: 'green')
  end
  User.create!(name: 'blue')
end

Kamome.anchor(:blue)  { User.count } # => 2
Kamome.anchor(:green) { User.count } # => 1
# >> Kamome: nil => :blue
# >>    (0.1ms)  begin transaction
# >>   SQL (0.4ms)  INSERT INTO "users" ("name") VALUES (?)  [["name", "blue"]]
# >>    (0.9ms)  commit transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => :green
# >>    (0.3ms)  begin transaction
# >>   SQL (0.2ms)  INSERT INTO "users" ("name") VALUES (?)  [["name", "green"]]
# >>    (0.9ms)  commit transaction
# >>    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :green => :green
# >> Kamome: :green => :green
# >> Kamome: :green => :blue
# >> Kamome: :blue => :green
# >> Kamome: :green => :blue
# >> Kamome: :blue => nil
# >> Kamome: nil => :blue
# >> [blue] Kamome: :blue => :green
# >> [blue] Kamome: :green => :blue
# >> Kamome: :blue => nil
# >> Kamome: nil => :blue
# >> [blue]    (0.0ms)  begin transaction
# >> [blue]   SQL (0.2ms)  INSERT INTO "users" ("name") VALUES (?)  [["name", "blue"]]
# >> [blue]    (0.7ms)  commit transaction
# >> [blue] Kamome: :blue => :green
# >> [blue] [green]    (0.1ms)  begin transaction
# >> [blue] [green]   SQL (0.3ms)  INSERT INTO "users" ("name") VALUES (?)  [["name", "green"]]
# >> [blue] [green]    (0.9ms)  commit transaction
# >> [blue] Kamome: :green => :blue
# >> [blue]    (0.0ms)  begin transaction
# >> [blue]   SQL (0.2ms)  INSERT INTO "users" ("name") VALUES (?)  [["name", "blue"]]
# >> [blue]    (0.9ms)  commit transaction
# >> Kamome: :blue => nil
# >> Kamome: nil => :blue
# >> [blue]    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :blue => nil
# >> Kamome: nil => :green
# >> [green]    (0.1ms)  SELECT COUNT(*) FROM "users"
# >> Kamome: :green => nil
