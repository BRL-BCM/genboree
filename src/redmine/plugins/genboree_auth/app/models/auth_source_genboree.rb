# Redmine MyApp Authentication Source
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Due to ActiveRecord design of storing state (current connection) in a *class*
# variable (that's some sweet grass you smokin'), let's have a new class for our
# ActiveReocrd-based connection to our alternative authentication database.
class GenboreeMainDB_ActiveRecord < ActiveRecord::Base
  PAUSE_RETRIES = 5
  MAX_RETRIES = 50
end

class AuthSourceGenboree < AuthSource
  # +login+ : what user entered for their login
  # +password+ : what user entered for their password
  def authenticate(login, password)
    retVal = nil
    unless(login.blank? or password.blank?)
      # Get a connection to the authenticating database.
      # - Don't use ActiveRecord::Base when using establish_connection() to get at
      #   your alternative database. Use class you prepped above.
      # - Use the fields of auth_sources to hold necessary information for
      #   performing the authentication against your db/authService. For accessing
      #   1+ tables in some other database, I like to use the columns like this:
      #   . "type" => MUST be this class's name the type of AR database adapter; usually "mysql" for me
      #   . "host" => who says the database is on the same host as the Redmine database???
      #   . "account" => username/account for connecting to the database
      #   . "account_password" => that username's password (who says these are the same
      #     as for the Redmine application?)
      #   . "base_dn" => while this field name is highly LDAP-ish, here we will take it to mean:
      #     "BASic Database Name data" and within is stored a string of the form {dbAdapterName}:{dbName}
      adapter, dbName = self.base_dn.split(':')
      retryCount = 0
      begin
        connPool = GenboreeMainDB_ActiveRecord.establish_connection(
          :adapter  => adapter,
          :host     => self.host,
          :port     => self.port,
          :username => self.account,
          :password => self.account_password,
          :database => dbName,
          :reconnect => true
        )
        db = connPool.checkout()
      rescue => err
        if(retryCount < GenboreeMainDB_ActiveRecord::MAX_RETRIES)
          sleep(1) if(retryCount < GenboreeMainDB_ActiveRecord::PAUSE_RETRIES)
          retryCount += 1
          #RAILS_DEFAULT_LOGGER.error("\n  ALT AUTH CONNECTION ERROR (will retry):\n  #{err.message}\n  " + err.backtrace.join("\n  "))
          connPool.disconnect!
          retry # start again at begin
        else # too many retries, serious, reraise error and let it fall through as it normally would in Rails.
          raise
        end
      end

      # Query the alternative authentication database for needed info. SQL
      # sufficient, obvious, and doesn't require other setup/LoC. Even more the
      # case if we have our database engine compute our digests (here, the whole username is a salt).
      # SQL also nice if your alt auth database doesn't have AR classes and is not part of a Rails app, etc.
      resultRow = db.select_one("SELECT name, firstName, lastName, email " +
                                "FROM genboreeuser " +
                                "WHERE SHA1(CONCAT(name, password)) = SHA1(CONCAT('#{db.quote_string(login)}', '#{db.quote_string(password)}'))") ;
      ::Rails.logger.error("\n  ALT AUTH QUERY RESULTS: #{resultRow.inspect}")

      unless(resultRow.nil? or resultRow.empty?)
        user = resultRow[self.attr_login]
        unless(user.nil? or user.empty?)
          retVal =
          {
            :firstname => resultRow[self.attr_firstname],
            :lastname => resultRow[self.attr_lastname],
            :mail => resultRow[self.attr_mail],
            :auth_source_id => self.id
          } if(onthefly_register?)
        end
      end
    end
    # ::Rails.logger.error("\n  ALT AUTH: retVal:\n    #{retVal.inspect}")
    connPool.checkin(db)
    return retVal
  end

  # test the connection to the LDAP
  def test_connection
  end

  def auth_method_name
    "Genboree"
  end
end
