require "./isucon5q-crystal/*"
require "kemal"
require "mysql"

module Isucon5q
  class Webapp
    # initialize

    def initialize(@env : HTTP::Server::Context)
      @user = User.new(0, "default_user", "df_user", "example@example.com")
      @db = DB.new
    end

    # structs

    struct User
      property id, account_name, nick_name, email

      def initialize(@id : Int32, @account_name : String, @nick_name : String, @email : String)
      end
    end

    struct Profile
      property user_id, first_name, last_name, sex, birthday, pref, update_at

      def initialize(@user_id : Int32, @first_name : String, @last_name : String, @sex : String, @birthday : Time, @pref : String, @update_at : Time)
      end
    end

    struct Entry
      property id, user_id, private_flag, title, content, created_at

      def initialize(@id : Int32, @user_id : Int32, @private_flag : Bool, @title : String, @content : String, @created_at : Time)
      end
    end

    struct Comment
      property id, entry_id, user_id, comment, created_at

      def initialize(@id : Int32, @entry_id : Int32, @user_id : Int32, @comment : String, @created_at : Time)
      end
    end

    struct Friend
      property id, created_at

      def initialize(@id : Int32, @created_at : Time)
      end
    end

    struct Footprint
      property user_id, owner_id, created_at, updated_at

      def initialize(@user_id : Int32, @owner_id : Int32, @created_at : Time, @updated_at : Time)
      end
    end

    # database class

    class DB
      def config
        @config ||= {
          db: {
            host:     "localhost",
            port:     3306_u16,
            username: "root",
            password: "",
            database: "isucon5q",
          },
        }
      end

      @conn : (MySQL::Connection | Nil)
      getter conn

      def conn
        @conn ||= MySQL.connect(
          config[:db][:host],
          config[:db][:username],
          config[:db][:password],
          config[:db][:database],
          config[:db][:port],
          nil # socket
        )
      end

      def exec(query : String)
        MySQL::Query.new(query).run(conn)
      end

      def exec(query : String, params)
        MySQL::Query.new(query, params).run(conn)
      end

      def exec(types : T, query : String)
        rows = MySQL::Query.new(query).run(conn)
        raise "query result is nil" if rows.is_a?(Nil)
        result = [] of typeof(first(types, rows))
        each(types, rows) { |r| result << r }
        result
      end

      def exec(types : T, query : String, params)
        rows = MySQL::Query.new(query, params).run(conn)
        raise "query result is nil" if rows.is_a?(Nil)
        result = [] of typeof(first(types, rows))
        each(types, rows) { |r| result << r }
        result
      end

      private def first(types : T, rows)
        each(types, rows) { |row| return row }
        raise "this should be unreachable"
      end

      macro generate_private_each(from, to)
        {% for n in (from..to) %}
        private def each(types : Tuple({% for i in (1...n) %}Class, {% end %} Class), rows)
          rows.each do |row|
            yield ({
              {% for j in (0...n) %}
                types[{{j}}].cast(row[{{j}}]),
              {% end %}
            })
          end
        end
        {% end %}
      end

      generate_private_each(1, 32)
    end

    # helper methods

    def authenticate(email, password)
      query = <<-SQL
        SELECT u.id AS id,
               u.account_name AS account_name,
               u.nick_name AS nick_name,
               u.email AS email
          FROM users u
          JOIN salts s ON u.id = s.user_id
         WHERE u.email = :email
           AND u.passhash = SHA2(CONCAT(:password, s.salt), 512)
      SQL
      result = @db.exec({Int32, String, String, String}, query, {"email" => email, "password" => password})
      id, account_name, nick_name, email = result.first
      user = User.new(id, account_name, nick_name, email)
      @env.session["user_id"] = user.id.to_s
      result
    end

    def current_user
      instance_user = @user
      return instance_user unless instance_user.id == 0
      return nil if @env.session["user_id"]?.is_a?(Nil)
      query = <<-SQL
        SELECT id, account_name, nick_name, email
          FROM users
         WHERE id=:user_id
      SQL
      result = @db.exec({Int32, String, String, String}, query, {"user_id" => @env.session["user_id"]})
      id, account_name, nick_name, email = result.first
      @user = User.new(id, account_name, nick_name, email)
    end

    def authenticated!
      return true if current_user
      @env.redirect "/login"
      return nil
    end

    def get_user(user_id : Int32)
      query = <<-SQL
        SELECT *
          FROM users
         WHERE id = :user_id
      SQL
      result = @db.exec({Int32, String, String, String, String}, query, {"user_id" => user_id})
      id, account_name, nick_name, email, passhash = result.first
      return User.new(id, account_name, nick_name, email)
    end

    def user_from_account(account_name : String)
      query = <<-SQL
        SELECT *
          FROM users
         WHERE account_name = :account_name
      SQL
      result = @db.exec({Int32, String, String, String, String}, query, {"account_name" => account_name})
      id, account_name, nick_name, email, passhash = result.first
      return User.new(id, account_name, nick_name, email)
    end

    def is_friend?(another_id : Int32)
      return false if @env.session["user_id"]?.is_a?(Nil)
      user_id = @env.session["user_id"]
      query = <<-SQL
        SELECT COUNT(1) AS cnt
          FROM relations
         WHERE (one = :user_id AND another = :another_id)
            OR (one = :another_id AND another = :user_id)
      SQL
      result = @db.exec({Int64}, query, {"user_id" => user_id, "another_id" => another_id})
      cnt = result.first.first
      cnt > 0 ? true : false
    end

    def is_friend_account?(name : String)
      user = user_from_account(name)
      return false if user.is_a?(Nil)
      is_friend?(user.id)
    end

    def permitted?(another_id : Int32)
      user = current_user
      return is_friend?(another_id) if user.is_a?(Nil)
      return true if another_id == user.id
      is_friend?(another_id)
    end

    def mark_footprint(id : Int32)
      user = current_user
      return nil if user.is_a?(Nil)
      if id != user.id
        query = <<-SQL
          INSERT INTO footprints (user_id,owner_id)
               VALUES (:user_id,:owner_id)
        SQL
        @db.exec(query, {"user_id" => id, "owner_id" => user.id})
      end
    end

    PREFS = ["未入力",
      "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県", "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県", "新潟県", "富山県",
      "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県", "鳥取県", "島根県",
      "岡山県", "広島県", "山口県", "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"]

    def prefectures
      PREFS
    end

    # endpoints

    def get_login
      @env.session.delete("user_id")
      message = "高負荷に耐えられるSNSコミュニティサイトへようこそ!"
      render "src/views/login.ecr"
    ensure
      @db.conn.close
    end

    def post_login
      email = @env.params.body["email"].to_s
      password = @env.params.body["password"].to_s
      return nil if authenticate(email, password).nil?
      @env.redirect "/"
    ensure
      @db.conn.close
    end

    def get_logout
      @env.session.delete("user_id")
      @env.redirect "/login"
    ensure
      @db.conn.close
    end

    def get_root
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      user = current_user
      return nil if user.is_a?(Nil)

      # profile

      query = <<-SQL
        SELECT *
          FROM profiles
         WHERE user_id = :user_id
      SQL
      result = @db.exec({Int32, String, String, String, Time, String, Time}, query, {"user_id" => user.id})
      user_id, first_name, last_name, sex, birthday, pref, updated_at = result.first
      profile = Profile.new(user_id, first_name, last_name, sex, birthday, pref, updated_at)

      # entries

      query = <<-SQL
          SELECT id, user_id, private, CAST(body as char(65535)), created_at
            FROM entries
           WHERE user_id = :user_id
        ORDER BY created_at LIMIT 5
      SQL
      result = @db.exec({Int32, Int32, Bool, Slice(UInt8), Time}, query, {"user_id" => user.id})
      entries = [] of Entry
      result.each do |record|
        id, user_id, private_flag, body, created_at = record
        title, content = HTML.escape(String.new(body, "UTF-8")).split('\n', 2)
        entries << Entry.new(id, user_id, private_flag, title, content, created_at)
      end

      # comments_for_me

      query = <<-SQL
          SELECT c.id AS id,
                 c.entry_id AS entry_id,
                 c.user_id AS user_id,
                 CAST(c.comment as char(65535)) AS comment,
                 c.created_at AS created_at
            FROM comments c
            JOIN entries e ON c.entry_id = e.id
           WHERE e.user_id = :user_id
        ORDER BY c.created_at DESC LIMIT 10
      SQL
      result = @db.exec({Int32, Int32, Int32, Slice(UInt8), Time}, query, {"user_id" => user.id})
      comments_for_me = [] of Comment
      result.each do |record|
        id, entry_id, user_id, comment, created_at = record
        comments_for_me << Comment.new(
          id,
          entry_id,
          user_id,
          HTML.escape(String.new(comment, "utf8")),
          created_at
        )
      end

      # entries_of_friends

      query = <<-SQL
          SELECT id, user_id, private, CAST(body as char(65535)), created_at
            FROM entries
        ORDER BY created_at DESC
           LIMIT 1000
      SQL
      result = @db.exec({Int32, Int32, Bool, Slice(UInt8), Time}, query)
      entries_of_friends = [] of Entry
      result.each do |record|
        id, user_id, private_flag, body, created_at = record
        title, content = HTML.escape(String.new(body, "UTF-8")).split('\n', 2)
        next if !is_friend?(user_id)
        entries_of_friends << Entry.new(id, user_id, private_flag, title, content, created_at)
        break if entries_of_friends.size >= 10
      end

      # comments_of_friends

      query = <<-SQL
          SELECT id, entry_id, user_id, CAST(comment as char(65535)), created_at
            FROM comments
        ORDER BY created_at DESC
           LIMIT 1000
      SQL
      result = @db.exec({Int32, Int32, Int32, Slice(UInt8), Time}, query)
      comments_of_friends = [] of Comment
      result.each do |record|
        id, entry_id, user_id, comment, created_at = record
        comment = HTML.escape(String.new(comment, "UTF-8"))
        c = Comment.new(id, entry_id, user_id, comment, created_at)
        next if !is_friend?(user_id)
        query = <<-SQL
          SELECT id, user_id, private, CAST(body as char(65535)), created_at
            FROM entries
           WHERE id = :entry_id
        SQL
        result = @db.exec({Int32, Int32, Bool, Slice(UInt8), Time}, query, {"entry_id" => entry_id})
        id, user_id, private_flag, body, created_at = result.first
        title, content = HTML.escape(String.new(body, "UTF-8")).split('\n', 2)
        entry = Entry.new(id, user_id, private_flag, title, content, created_at)
        next if entry.private_flag && !permitted?(entry.user_id)
        comments_of_friends << c
        break if comments_of_friends.size >= 10
      end

      # friends_map

      query = <<-SQL
          SELECT *
            FROM relations
           WHERE one = :user_id
              OR another = :user_id
        ORDER BY created_at DESC
      SQL
      result = @db.exec({Int32, Int32, Int32, Time}, query, {"user_id" => user.id})
      friends_map = {} of Int32 => Time
      result.each do |record|
        id, one, another, created_at = record
        friend_id = (one == user.id) ? another : one
        friends_map[friend_id] = created_at unless friends_map.has_key?(friend_id)
      end
      friends = [] of Friend
      friends_map.each do |key, val|
        friends << Friend.new(key, val)
      end

      # footprints

      query = <<-SQL
          SELECT user_id,
                 owner_id,
                 DATE(created_at) AS date,
                 MAX(created_at) AS updated
            FROM footprints
           WHERE user_id = :user_id
        GROUP BY user_id, owner_id, DATE(created_at)
        ORDER BY updated DESC
           LIMIT 10
      SQL
      result = @db.exec({Int32, Int32, Time, Time}, query, {"user_id" => user.id})
      footprints = [] of Footprint
      result.each do |record|
        user_id, owner_id, date, updated = record
        footprints << Footprint.new(user_id, owner_id, date, updated)
      end

      render "src/views/index.ecr"
    ensure
      @db.conn.close
    end

    def get_profile_account_name
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      account_name = @env.params.url["account_name"].to_s
      owner = user_from_account(account_name)

      query = <<-SQL
        SELECT *
          FROM profiles
         WHERE user_id = :user_id
      SQL
      result = @db.exec({Int32, String, String, String, Time, String, Time}, query, {"user_id" => owner.id})
      user_id, first_name, last_name, sex, birthday, pref, updated_at = result.first
      prof = Profile.new(user_id, first_name, last_name, sex, birthday, pref, updated_at)

      query = if permitted?(owner.id)
                <<-SQL
                    SELECT id, user_id, private, CAST(body as char(65535)), created_at
                      FROM entries
                     WHERE user_id = :user_id
                  ORDER BY created_at
                     LIMIT 5
                SQL
              else
                <<-SQL
                    SELECT id, user_id, private, CAST(body as char(65535)), created_at
                      FROM entries
                     WHERE user_id = :user_id
                       AND private=0
                  ORDER BY created_at
                     LIMIT 5
                SQL
              end

      result = @db.exec({Int32, Int32, Bool, Slice(UInt8), Time}, query, {"user_id" => owner.id})
      entries = [] of Entry
      result.each do |record|
        id, user_id, private_flag, body, created_at = record
        title, content = HTML.escape(String.new(body, "UTF-8")).split('\n', 2)
        entries << Entry.new(id, user_id, private_flag, title, content, created_at)
      end
      mark_footprint(owner.id)

      profile = prof
      owner_private = permitted?(owner.id)

      c_user = current_user
      return nil if c_user.is_a?(Nil)

      render "src/views/profile.ecr"
    ensure
      @db.conn.close
    end

    def post_profile_account_name
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      account_name = @env.params.url["account_name"].to_s
      owner = user_from_account(account_name)

      c_user = current_user
      return nil if c_user.is_a?(Nil)

      if account_name != c_user.account_name
        @env.response.status_code = 401
        return nil
      end

      args = {
        "user_id"    => c_user.id,
        "last_name"  => @env.params.body["last_name"],
        "first_name" => @env.params.body["first_name"],
        "sex"        => @env.params.body["sex"],
        "birthday"   => @env.params.body["birthday"],
        "pref"       => @env.params.body["pref"],
      }

      query = "SELECT * FROM profiles WHERE user_id = :user_id"
      result = @db.exec({Int32, String, String, String, Time, String, Time}, query, {"user_id" => c_user.id})
      unless result.first.is_a?(Nil)
        query = <<-SQL
          UPDATE profiles
             SET first_name = :first_name,
                 last_name  = :last_name,
                 sex        = :sex,
                 birthday   = :birthday,
                 pref       = :pref,
                 updated_at = CURRENT_TIMESTAMP()
           WHERE user_id = :user_id
        SQL
      else
        query = <<-SQL
          INSERT INTO profiles (user_id, first_name, last_name, sex, birthday, pref)
               VALUES (:user_id, :first_name, :last_name, :sex, :birthday, :pref)
        SQL
      end
      @db.exec(query, args)
      @env.redirect "/profile/#{account_name}"
    ensure
      @db.conn.close
    end

    def get_diary_entries_account_name
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      account_name = @env.params.url["account_name"].to_s
      owner = user_from_account(account_name)

      query = if permitted?(owner.id)
                <<-SQL
                    SELECT id, user_id, private, CAST(body as char(65535)), created_at
                      FROM entries
                     WHERE user_id = :user_id
                  ORDER BY created_at DESC
                     LIMIT 20
                SQL
              else
                <<-SQL
                    SELECT id, user_id, private, CAST(body as char(65535)), created_at
                      FROM entries
                     WHERE user_id = :user_id
                       AND private=0
                  ORDER BY created_at DESC
                     LIMIT 20
                SQL
              end

      result = @db.exec({Int32, Int32, Bool, Slice(UInt8), Time}, query, {"user_id" => owner.id})
      entries = [] of Entry
      result.each do |record|
        id, user_id, private_flag, body, created_at = record
        title, content = HTML.escape(String.new(body, "UTF-8")).split('\n', 2)
        entries << Entry.new(id, user_id, private_flag, title, content, created_at)
      end
      mark_footprint(owner.id)

      c_user = current_user
      return nil if c_user.is_a?(Nil)
      myself = c_user.is_a?(Nil) ? false : (c_user.id == owner.id)

      render "src/views/entries.ecr"
    ensure
      @db.conn.close
    end

    def get_diary_entry_entry_id
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      entry_id = @env.params.url["entry_id"].to_i
      query = <<-SQL
        SELECT id, user_id, private, CAST(body as char(65535)), created_at
          FROM entries
         WHERE id = :entry_id
      SQL
      result = @db.exec({Int32, Int32, Bool, Slice(UInt8), Time}, query, {"entry_id" => entry_id})
      entries = [] of Entry
      id, user_id, private_flag, body, created_at = result.first
      title, content = HTML.escape(String.new(body, "UTF-8")).split('\n', 2)
      entry = Entry.new(id, user_id, private_flag, title, content, created_at)
      owner = get_user(entry.user_id)

      if entry.private_flag && !permitted?(owner.id)
        @env.response.status_code = 403
        return nil
      end

      query = <<-SQL
        SELECT id, entry_id, user_id, CAST(comment as char(65535)), created_at
          FROM comments
         WHERE entry_id = :entry_id
      SQL
      result = @db.exec({Int32, Int32, Int32, Slice(UInt8), Time}, query, {"entry_id" => entry.id})
      comments = [] of Comment
      result.each do |record|
        id, entry_id, user_id, comment, created_at = record
        comment = HTML.escape(String.new(comment, "UTF-8"))
        comments << Comment.new(id, entry_id, user_id, comment, created_at)
      end
      mark_footprint(owner.id)

      render "src/views/entry.ecr"
    ensure
      @db.conn.close
    end

    def post_diary_entry
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      private_flag = @env.params.body.has_key?("private") ? "1" : "0"
      title = @env.params.body["title"]
      content = @env.params.body["content"]
      body = (title || "タイトルなし") + "\n" + content

      c_user = current_user
      return nil if c_user.is_a?(Nil)

      query = <<-SQL
        INSERT INTO entries (user_id, private, body)
             VALUES (:user_id, :private_flag, :body)
      SQL
      @db.exec(query, {"user_id" => c_user.id, "private_flag" => private_flag, "body" => body})
      @env.redirect "/diary/entries/#{c_user.account_name}"
    ensure
      @db.conn.close
    end

    def post_diary_comment_entry_id
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      entry_id = @env.params.url["entry_id"].to_i
      query = <<-SQL
        SELECT id, user_id, private, CAST(body as char(65535)), created_at
          FROM entries
         WHERE id = :entry_id
      SQL
      result = @db.exec({Int32, Int32, Bool, Slice(UInt8), Time}, query, {"entry_id" => entry_id})
      entries = [] of Entry
      id, user_id, private_flag, body, created_at = result.first
      title, content = HTML.escape(String.new(body, "UTF-8")).split('\n', 2)
      entry = Entry.new(id, user_id, private_flag, title, content, created_at)

      if entry.private_flag && !permitted?(entry.user_id)
        @env.response.status_code = 401
        return nil
      end

      c_user = current_user
      return nil if c_user.is_a?(Nil)

      query = <<-SQL
        INSERT INTO comments (entry_id, user_id, comment)
             VALUES (:entry_id, :user_id, :comment)
      SQL
      @db.exec(query, {"entry_id" => entry.id, "user_id" => c_user.id, "comment" => @env.params.body["comment"]})
      @env.redirect "/diary/entry/#{entry.id}"
    ensure
      @db.conn.close
    end

    def get_footprints
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      c_user = current_user
      return nil if c_user.is_a?(Nil)

      query = <<-SQL
          SELECT user_id,
                 owner_id,
                 DATE(created_at) AS date,
                 MAX(created_at) as updated
            FROM footprints
           WHERE user_id = :user_id
        GROUP BY user_id, owner_id, DATE(created_at)
        ORDER BY updated DESC
           LIMIT 50
      SQL
      result = @db.exec({Int32, Int32, Time, Time}, query, {"user_id" => c_user.id})
      footprints = [] of Footprint
      result.each do |record|
        user_id, owner_id, date, updated = record
        footprints << Footprint.new(user_id, owner_id, date, updated)
      end
      render "src/views/footprints.ecr"
    ensure
      @db.conn.close
    end

    def get_friends
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      c_user = current_user
      return nil if c_user.is_a?(Nil)

      query = <<-SQL
          SELECT *
            FROM relations
           WHERE one = :one
              OR another = :another
        ORDER BY created_at DESC
      SQL
      result = @db.exec({Int32, Int32, Int32, Time}, query, {"one" => c_user.id, "another" => c_user.id})
      friends = [] of Friend
      result.each do |record|
        id, one, another, created_at = record
        key_id = (one == c_user.id ? another : one)
        next if friends.map { |f| f.id }.includes?(key_id)
        friends << Friend.new(key_id, created_at)
      end
      render "src/views/friends.ecr"
    ensure
      @db.conn.close
    end

    def post_friends_account_name
      auth = authenticated!
      return nil if auth.is_a?(Nil)

      c_user = current_user
      return nil if c_user.is_a?(Nil)

      account_name = @env.params.url["account_name"].to_s
      unless is_friend_account?(account_name)
        user = user_from_account(account_name)
        unless user
          @env.response.status_code = 404
          return nil
        end
        query = <<-SQL
          INSERT INTO relations (one, another)
               VALUES (:current_user_id, :account_name_user_id),
                      (:account_name_user_id, :current_user_id)
        SQL
        @db.exec(query, {"current_user_id" => c_user.id, "account_name_user_id" => user.id})
        @env.redirect "/friends"
      end
    ensure
      @db.conn.close
    end

    # initialize endpoint

    def get_initialize
      @db.exec("DELETE FROM relations  WHERE id >  500000")
      @db.exec("DELETE FROM footprints WHERE id >  500000")
      @db.exec("DELETE FROM entries    WHERE id >  500000")
      @db.exec("DELETE FROM comments   WHERE id > 1500000")
    ensure
      @db.conn.close
    end
  end
end

error 401 do |env|
  env.session.delete("user_id")
  message = "ログインに失敗しました"
  render "src/views/login.ecr"
end

error 403 do |env|
  message = "友人のみしかアクセスできません"
  render "src/views/error.ecr"
end

error 404 do |env|
  message = "要求されたコンテンツは存在しません"
  render "src/views/error.ecr"
end

get "/login" { |env| Isucon5q::Webapp.new(env).get_login }
post "/login" { |env| Isucon5q::Webapp.new(env).post_login }
get "/logout" { |env| Isucon5q::Webapp.new(env).get_logout }
get "/" { |env| Isucon5q::Webapp.new(env).get_root }
get "/profile/:account_name" { |env| Isucon5q::Webapp.new(env).get_profile_account_name }
post "/profile/:account_name" { |env| Isucon5q::Webapp.new(env).post_profile_account_name }
get "/diary/entries/:account_name" { |env| Isucon5q::Webapp.new(env).get_diary_entries_account_name }
get "/diary/entry/:entry_id" { |env| Isucon5q::Webapp.new(env).get_diary_entry_entry_id }
post "/diary/entry" { |env| Isucon5q::Webapp.new(env).post_diary_entry }
post "/diary/comment/:entry_id" { |env| Isucon5q::Webapp.new(env).post_diary_comment_entry_id }
get "/footprints" { |env| Isucon5q::Webapp.new(env).get_footprints }
get "/friends" { |env| Isucon5q::Webapp.new(env).get_friends }
post "/friends/:account_name" { |env| Isucon5q::Webapp.new(env).post_friends_account_name }
get "/initialize" { |env| Isucon5q::Webapp.new(env).get_initialize }

serve_static({"gzip" => false})

Kemal.run
