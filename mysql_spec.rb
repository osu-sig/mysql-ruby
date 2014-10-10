require_relative 'mysql'
require 'simplecov'
require 'simplecov-rcov'

SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start

describe Mysql do
    db = Mysql.new
  describe "#Create valid connection" do
    it "connects successfully" do
      db.connect('root', '').should == true
    end
  end
  describe "#Create invalid connection" do
    it "fails to connect" do
      db.connect('root', 'adsf').should == false
    end
  end
  describe "#create_database('newdb')" do
    it "create a new database named newdb" do
      db.connect('root', '')
      db.create_database('newdb').should == true
      db.verify_database_present('newdb').should == true
    end
  end
  describe "#create_database('newdb') when it already exists" do
    it "fails to create a dupe database" do
      db.connect('root', '')
      db.create_database('newdb').should_not == true
      db.verify_database_present('newdb').should == true
    end
  end
  describe "#create_user('bondo', 'password)" do
    it "creates the user bondo" do
      db.connect('root', '')
      db.create_user('bondo', 'password').should == true
      db.verify_user_present('bondo').should == true
      db.verify_user_credentials('bondo','password').should == true
    end
  end
  describe "#create_user('bondo', 'password)" do
    it "fails to create a dupe user" do
      db.connect('root', '')
      db.create_user('bondo', 'password').should_not == true
      db.verify_user_present('bondo').should == true
      db.verify_user_credentials('bondo','password').should == true
    end
  end
  describe "#create_user_grant('newdb', 'bondo', 'SELECT')" do
    it "grants bondo rights to newdb" do
      db.connect('root', '')
      db.create_user_grant('newdb', 'bondo', 'SELECT').should == true
      db.verify_user_grant_present('newdb', 'bondo').should == true
    end
  end
  describe "#update_user_password('bondo', 'newpassword')" do
    it "changes password for user bondo" do
      db.connect('root', '')
      db.update_user_password('bondo', 'newpassword').should == true
      db.verify_user_present('bondo').should == true
      db.verify_user_credentials('bondo','password').should_not == true
      db.verify_user_credentials('bondo','newpassword').should == true
    end
  end
  describe "#rename_user('bondo', 'hondo')" do
    it "renames bondo to hondo" do
      db.connect('root', '')
      db.rename_user('bondo', 'hondo').should == true
      db.verify_user_present('hondo').should == true
      db.verify_user_present('bondo').should_not == true
      db.verify_user_credentials('hondo','newpassword').should == true
      db.verify_user_credentials('bondo','newpassword').should_not == true
      db.verify_user_grant_present('newdb','hondo').should == true
      db.verify_user_grant_present('newdb','bondo').should_not == true
    end
  end
  describe "#revoke_user_grant('newdb', 'hondo')" do
    it "removes grants for bondo on newdb" do
      db.connect('root', '')
      db.revoke_user_grant('newdb', 'hondo').should == true
      db.verify_user_grant_present('newdb','hondo').should_not == true
    end
  end
  describe "#drop_user('hondo', 'password)" do
    it "drops the user hondo" do
      db.connect('root', '')
      db.drop_user('hondo').should == true
      db.verify_user_present('hondo').should_not == true
      db.verify_user_credentials('hondo','password').should == false
    end
  end
  describe "#dump_database('localhost','newdb')" do
    it "dumps database named newdb" do
      db.dump_database('localhost','newdb').should == true
      #verify dump file is present
    end
  end
  describe "#dump_database('localhost','notnewdb')" do
    it "fails to dump non existant db named notnewdb" do
      db.dump_database('localhost','notnewdb').should == false
      #verify empty dump file is not present
    end
  end
  describe "#drop_database('newdb')" do
    it "drops database named newdb" do
      db.connect('root', '')
      db.drop_database('newdb').should == true
      db.verify_database_present('newdb').should_not == true
      db.verify_database_grants_purged('newdb').should == true
    end
  end
  
end