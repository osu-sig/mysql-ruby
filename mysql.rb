require 'rubygems'
require 'mysql2'

class Mysql
  
    # Initialize our Mysql object with some instance variables
    def initialize
      @run = true
      @test = true
      @debug = true
      @host = 'localhost'
    end
    
    # Create a connection to a database server with given credentials for 
    # user, password, host, and type
    def connect(user, password, host="localhost")
      
      begin
        # Set up our instance variables so we know where and what we are connected to
        @host = host
        
        # Set up the connection string
        connection_string = sprintf("host=%s",@host)
        
        display_command("attempting to connect with credentials: #{connection_string} user: #{user} passwd: #{password}") if @show
        
        # Attempt to connect to the database
        @dbh = Mysql2::Client.new(:host => @host, :username => user, :password => password)
        
        # Assign user host restrictions for this server based
        # on whether or not this is a master or slave
        @user_host_restriction = set_user_host_restriction
        
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Create a new database on the server with specified name
    # this must be a unique name
    def create_database(database)
      
      sql = "CREATE DATABASE `#{database}`"
      
      display_command(sql) if @show 
      
      begin
        @dbh.query(sql) if @run
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Drop given database and remove any grants it may have associated with it
    def drop_database(database)

      sql = "DROP DATABASE `#{database}`"

      display_command(sql) if @show
        
      begin
        @dbh.query(sql) if @run
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Dump the specified database and return a sql file
    def dump_database(host, database)
      
      begin
        
        # Redirect output to stdout so we can see if it failed or succeeded
        result = %x(mysqldump --opt --user=root --host=#{host} #{database} > #{database}.sql 2>&1)
        unless $? == 0 #check if the child process exited cleanly.
          
          # Clean up our poor empty file
          %x(rm #{database}.sql)
          return false
        end
        
        return true
        
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Duplicate a database onto another host
    def clone_database
      
    end
    
    # Move a database from one host to another
    def move_database
      
    end
    
    # Create database user with specified name on the server
    def create_user(user, password)
      
      sql = "CREATE USER #{full_name(user)} IDENTIFIED BY '#{password}'"
      
      display_command(sql) if @show
      
      begin
        @dbh.query(sql) if @run
        flush_privileges
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Delete an existing database user. Before deleting the user remove any/all grants
    # they have been assigned to any databases on this server
    def drop_user(user)
      
      sql = "DROP USER #{full_name(user)}"
      
      display_command(sql) if @show

      begin
        @dbh.query(sql) if @run
        flush_privileges
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Create an entry in the grant table for the specified combination of 
    # user, database, and rights. We used to have hard coded role logic in 
    # here to the effect of:
    # ADMIN = 'ALL PRIVILEGES'
    # WEB   = 'SELECT,INSERT,UPDATE,DELETE,LOCK TABLES,EXECUTE'
    # READONLY = 'SELECT'
    def create_user_grant(database, user, permissions)
      
      sql = "GRANT #{permissions} ON `#{database}`.* TO #{full_name(user)}"
      
      display_command(sql) if @show  
        
      begin
        @dbh.query(sql) if @run
        flush_privileges
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end

    end
    
    # Revoke a specific grant entry for a user. This will remove a users permission
    # to an individual specified database
    def revoke_user_grant(database, user)
      
      sql = "REVOKE ALL PRIVILEGES ON `#{database}`.* FROM #{full_name(user)}"

      display_command(sql) if @show
  
      begin
        @dbh.query(sql) if @run
        flush_privileges
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Update a users password with specified username and password pair
    def update_user_password(user, password)
      
      sql = "UPDATE mysql.user SET Password=PASSWORD('#{password}') WHERE User='#{user}' AND Host='#{@user_host_restriction}'"

      display_command(sql) if @show
      
      begin
        @dbh.query(sql) if @run
        flush_privileges
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Update a users password with specified username and password pair
    def rename_user(user, new_user_name)

      sql = "RENAME USER #{full_name(user)} TO #{full_name(new_user_name)}"

      display_command(sql) if @show

      begin
        @dbh.query(sql) if @run
        flush_privileges
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end

    end
    
    # Verify whether a database is present or not on the server by
    # attempting to use it...if it is there it will execute successfully
    # if it is not it will throw an error which we catch and return as false
    def verify_database_present(database)
      
      begin
        # Attempt to use the database with given name
        result = @dbh.query("USE #{database}")
         
        # If we did not just throw an error the database is present
        return true
        
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Verify that given user is present on server
    def verify_user_present(user)
      
      begin
        # See if we can find the user...a valid user will return one or more rows...and invalid will return 0
        result = @dbh.query("SELECT User FROM mysql.user WHERE User='#{user}' AND Host='#{@user_host_restriction}'")
        
        # If we got a result the user is present...otherwise they are not
        return result.count >= 1 ? true : false
        
      rescue => e
        display_error(e) if @debug
      end
      
    end 
    
    # Verify whether a given grant exists for the given user on the given database.
    # If the user is nonexistant it will throw an error on the show command which is why 
    # we trap the error and return false as this is still consistent
    def verify_user_grant_present(database, user)
      
      begin
        grant_present = false
        
        begin
          # This block will throw error and fail if user is not valid...
          results = @dbh.query("SHOW GRANTS FOR #{full_name(user)}")
          
          results.each do |row|
            
            # Convert result to a string and look to see if we have a match
            if current_database = row.to_s().index(database)
              grant_present = true
              break
            end
          end
        rescue
          grant_present = false
        end
        
        return grant_present
      rescue => e
        display_error(e) if @debug
      end
      
    end
    
    # Verify a given set of user credentials is valid...used primarily after a user name change 
    # or password change to verify the changes have taken place and are valid
    def verify_user_credentials(user, password)
      
      begin
        # Set up the connection string
        connection_string = sprintf("host=%s",@host)
        
        display_command("attempting to verify credentials: #{connection_string} user: #{user} passwd: #{password}") if @show
      
        # Attempt to connect to the database
        return true if Mysql2::Client.new(:host => @host, :username => user, :password => password)
        
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Verify that all grants for a database have been purged. This is primarily used 
    # to ensure that after dropping a database we have really removed all the grants 
    # associtated with it.
    def verify_database_grants_purged(database)
      #TODO: create actual test
      return true
    end
    
private
    
    # Assign a host restriction to all users created on this database server 
    # based on whether or not it is a master or slave
    def set_user_host_restriction
      
      # For testing purposes we need to restrict this to localhost or something
      # else that makes sense in future
      host = (@test == true) ? 'localhost' : '%.cws.oregonstate.edu'
      
      # If we are on a database host that is a slave we assign new users
      # a different host restriction than if we are on a master
      is_slave? ? '%' : host
      
    end
    
    # This is a mysql specific status check...we will need to broaden our scope
    # to deal with postgres status...and if we are mysqlite we should just
    # always answer false as the concept is not applicable
    def is_slave?
      
      begin
        # Query our slave running status
        result = @dbh.query("SHOW SLAVE STATUS")
        
        # If its not a slave we wont get anything (or its off) otherwise its a master
        return result.count > 0 ? true : false
        
      rescue => e
        display_error(e) if @debug
      end
      
    end
    
    # Flush the datbase privileges (after you have created or modified a users grants)
    def flush_privileges
      
      begin
        @dbh.query("FLUSH PRIVILEGES")
        return true
      rescue => e
        display_error(e) if @debug
        return false
      end
      
    end
    
    # Format our errors for display 
    def display_error(error)  
      puts "Error: #{error.message}"
    end
    
    # Format our sql for display if they have @show enabled
    def display_command(cmd)
      print "\t#{cmd}\n"
    end
    
    # Format our user name to its full form including the host restriction
    def full_name(user)
      return "'#{user}'@'#{@user_host_restriction}'"
    end
    
end