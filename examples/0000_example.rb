# 一番シンプルな使い方

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
        end
      end
    end
  end
end

# Kamome の初期設定
Kamome.config.database_config = database_config
ActiveRecord::Base.include(Kamome::Model)

# 対応させるモデルには kamome を記述
class User < ActiveRecord::Base
  kamome
end

# 使い方
Kamome.anchor(:blue) do
  User.create!
  User.count                    # => 

  Kamome.anchor(:green) do
    User.count                  # => 
  end
end
# ~> /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler/definition.rb:179:in `rescue in specs': Your bundle is locked to json (1.8.3), but that version could not be found in any of the sources listed in your Gemfile. If you haven't changed sources, that means the author of json (1.8.3) has removed it. You'll need to update your bundle to a different version of json (1.8.3) that hasn't been removed in order to install. (Bundler::GemNotFound)
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler/definition.rb:173:in `specs'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler/definition.rb:233:in `specs_for'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler/definition.rb:222:in `requested_specs'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler/runtime.rb:118:in `block in definition_method'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler/runtime.rb:19:in `setup'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler.rb:99:in `setup'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/gems/2.4.0/gems/bundler-1.13.7/lib/bundler/setup.rb:20:in `<top (required)>'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:133:in `require'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:133:in `rescue in require'
# ~> 	from /usr/local/var/rbenv/versions/2.4.0/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:40:in `require'
# ~> 	from -:3:in `<main>'
